import '../database/database_helper.dart';
import '../models/detail_penjualan.dart';
import '../models/penjualan.dart';

/// Item yang dijual dalam satu transaksi.
class ItemJual {
  final int idBarang;
  final int jumlah;
  final double hargaJual;
  final double hargaBeli;

  const ItemJual({
    required this.idBarang,
    required this.jumlah,
    required this.hargaJual,
    required this.hargaBeli,
  });

  double get subtotal => jumlah * hargaJual;
  double get keuntungan => jumlah * (hargaJual - hargaBeli);
}

class PenjualanService {
  /// Menyimpan transaksi penjualan beserta detailnya dan
  /// mengurangi stok barang dalam satu transaksi SQLite.
  ///
  /// Pembayaran yang nilainya kurang dari total DITOLAK
  /// sebelum data disimpan.
  Future<Penjualan> buatTransaksi({
    required List<ItemJual> items,
    required double bayar,
    int? idUser,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Keranjang tidak boleh kosong');
    }

    for (final item in items) {
      if (item.idBarang <= 0 || item.jumlah <= 0) {
        throw ArgumentError('Barang dan jumlah harus valid');
      }

      if (!item.hargaJual.isFinite ||
          item.hargaJual < 0 ||
          !item.hargaBeli.isFinite ||
          item.hargaBeli < 0) {
        throw ArgumentError('Harga barang harus bernilai valid dan tidak negatif');
      }
    }

    final db = await DatabaseHelper.instance.database;

    if (idUser != null) {
      final userRows = await db.rawQuery(
        'SELECT 1 FROM users WHERE id_user = ? LIMIT 1',
        [idUser],
      );

      if (userRows.isEmpty) {
        throw StateError('Akun kasir tidak ditemukan atau tidak aktif.');
      }
    }

    final total = items.fold(0.0, (nilai, item) => nilai + item.subtotal);

    if (!total.isFinite || !bayar.isFinite || bayar < 0) {
      throw ArgumentError('Total dan pembayaran harus bernilai valid');
    }

    if (bayar < total) {
      throw ArgumentError('Pembayaran kurang dari total');
    }

    final kembalian = bayar - total;
    final tanggal = DateTime.now().toIso8601String();
    final nomorTransaksi = _buatNomorTransaksi();

    late Penjualan penjualan;

    await db.transaction((txn) async {
      final idPenjualan = await txn.insert('penjualan', {
        'nomor_transaksi': nomorTransaksi,
        'tanggal': tanggal,
        'total': total,
        'bayar': bayar,
        'kembalian': kembalian,
        'id_user': idUser,
      });

      for (final item in items) {
        // Periksa stok di dalam transaksi.
        final stokRows = await txn.rawQuery(
          'SELECT stok FROM barang WHERE id_barang = ?',
          [item.idBarang],
        );

        if (stokRows.isEmpty) {
          throw StateError('Barang tidak ditemukan');
        }

        final stok = stokRows.first['stok'] as int;

        if (stok < item.jumlah) {
          throw StateError('Stok barang tidak mencukupi');
        }

        await txn.insert('detail_penjualan', {
          'id_penjualan': idPenjualan,
          'id_barang': item.idBarang,
          'jumlah': item.jumlah,
          'harga_jual': item.hargaJual,
          'harga_beli': item.hargaBeli,
          'subtotal': item.subtotal,
          'keuntungan': item.keuntungan,
        });

        // Kurangi stok barang.
        await txn.rawUpdate(
          'UPDATE barang SET stok = stok - ?, updated_at = ? WHERE id_barang = ?',
          [item.jumlah, tanggal, item.idBarang],
        );
      }

      penjualan = Penjualan(
        idPenjualan: idPenjualan,
        nomorTransaksi: nomorTransaksi,
        tanggal: tanggal,
        total: total,
        bayar: bayar,
        kembalian: kembalian,
        idUser: idUser,
      );
    });

    return penjualan;
  }

  Future<List<Penjualan>> getRiwayat({int limit = 100}) async {
    final db = await DatabaseHelper.instance.database;

    final maps = await db.query(
      'penjualan',
      orderBy: 'tanggal DESC, id_penjualan DESC',
      limit: limit,
    );

    return maps.map(Penjualan.fromMap).toList();
  }

  Future<Penjualan?> getById(int id) async {
    final db = await DatabaseHelper.instance.database;

    final maps = await db.query(
      'penjualan',
      where: 'id_penjualan = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    return Penjualan.fromMap(maps.first);
  }

  Future<List<DetailPenjualan>> getDetail(int idPenjualan) async {
    final db = await DatabaseHelper.instance.database;

    final maps = await db.rawQuery(
      '''
      SELECT detail_penjualan.*, barang.nama_barang, barang.kode_barang
      FROM detail_penjualan
      JOIN barang ON barang.id_barang = detail_penjualan.id_barang
      WHERE detail_penjualan.id_penjualan = ?
      ORDER BY detail_penjualan.id_detail_penjualan ASC
    ''',
      [idPenjualan],
    );

    return maps.map(DetailPenjualan.fromMap).toList();
  }

  Future<List<Penjualan>> getRiwayatPeriode({
    required String tanggalMulai,
    String? tanggalSelesai,
  }) async {
    final db = await DatabaseHelper.instance.database;

    final where = tanggalSelesai == null
        ? "WHERE tanggal >= ?"
        : "WHERE tanggal >= ? AND tanggal < ?";

    final args = tanggalSelesai == null
        ? [tanggalMulai]
        : [tanggalMulai, tanggalSelesai];

    final maps = await db.rawQuery(
      'SELECT * FROM penjualan $where ORDER BY tanggal DESC, id_penjualan DESC',
      args,
    );

    return maps.map(Penjualan.fromMap).toList();
  }

  /// Ringkasan keuntungan dalam periode tanggal ISO.
  ///
  /// Penjualan bersih dihitung dengan mengurangi
  /// total penjualan kotor dengan total nilai
  /// retur yang disetujui pada periode yang sama.
  ///
  /// Keuntungan disesuaikan dengan retur:
  /// - Barang layak dijual kembali: keuntungan
  ///   dikembalikan sebesar (harga jual asli -
  ///   harga beli asli) × jumlah retur.
  /// - Barang rusak: seluruh harga jual asli
  ///   × jumlah retur dikurangi (keuntungan
  ///   dibatalkan dan harga pokok barang rusak
  ///   menjadi kerugian).
  Future<Map<String, double>> ringkasanKeuntungan({
    required String tanggalMulai,
    String? tanggalSelesai,
  }) async {
    final db = await DatabaseHelper.instance.database;

    final wherePenjualan = tanggalSelesai == null
        ? 'tanggal >= ?'
        : 'tanggal >= ? AND tanggal < ?';
    final whereDetail = tanggalSelesai == null
        ? 'p.tanggal >= ?'
        : 'p.tanggal >= ? AND p.tanggal < ?';
    final whereRetur = tanggalSelesai == null
        ? 'r.tanggal >= ?'
        : 'r.tanggal >= ? AND r.tanggal < ?';
    final args = tanggalSelesai == null
        ? [tanggalMulai]
        : [tanggalMulai, tanggalSelesai];

    // Penjualan kotor. Dijumlah dari tabel
    // penjualan saja agar total tidak
    // terlipat ganda oleh banyaknya detail.
    final penjualanRow = await db.rawQuery('''
      SELECT COALESCE(SUM(total), 0) AS total_penjualan
      FROM penjualan
      WHERE $wherePenjualan
    ''', args);

    // Keuntungan dari detail penjualan asli.
    final keuntunganRow = await db.rawQuery('''
      SELECT COALESCE(SUM(dp.keuntungan), 0) AS keuntungan
      FROM detail_penjualan dp
      JOIN penjualan p ON p.id_penjualan = dp.id_penjualan
      WHERE $whereDetail
    ''', args);

    // Total nilai retur pada periode yang sama.
    final returRow = await db.rawQuery('''
      SELECT COALESCE(SUM(dr.subtotal), 0) AS total_retur
      FROM retur r
      JOIN detail_retur dr ON dr.id_retur = r.id_retur
      WHERE $whereRetur
    ''', args);

    // Penyesuaian keuntungan dari retur.
    // Harga beli asli dibaca dari detail
    // penjualan asli, bukan harga barang kini.
    final penyesuaianRow = await db.rawQuery('''
      SELECT COALESCE(SUM(
        CASE
          WHEN dr.kondisi = 'rusak'
            THEN dr.harga_satuan * dr.jumlah
          ELSE (dr.harga_satuan - dp.harga_beli) * dr.jumlah
        END
      ), 0) AS penyesuaian
      FROM detail_retur dr
      JOIN retur r ON r.id_retur = dr.id_retur
      JOIN detail_penjualan dp
        ON dp.id_detail_penjualan = dr.id_detail_penjualan
      WHERE $whereRetur
    ''', args);

    final pengeluaranRow = await db.rawQuery('''
      SELECT COALESCE(SUM(nominal), 0) AS total
      FROM pengeluaran
      WHERE tanggal >= ?${tanggalSelesai != null ? ' AND tanggal < ?' : ''}
    ''', args);

    final totalPenjualan =
        (penjualanRow.first['total_penjualan'] as num).toDouble();
    final keuntunganPenjualan =
        (keuntunganRow.first['keuntungan'] as num).toDouble();
    final totalRetur =
        (returRow.first['total_retur'] as num).toDouble();
    final penyesuaian =
        (penyesuaianRow.first['penyesuaian'] as num).toDouble();
    final pengeluaran =
        (pengeluaranRow.first['total'] as num).toDouble();

    final keuntunganKotor = keuntunganPenjualan - penyesuaian;

    return {
      'total_penjualan': totalPenjualan,
      'total_retur': totalRetur,
      'penjualan_bersih': totalPenjualan - totalRetur,
      'keuntungan_kotor': keuntunganKotor,
      'pengeluaran': pengeluaran,
      'keuntungan_bersih': keuntunganKotor - pengeluaran,
    };
  }

  /// Penjualan bersih per hari untuk 7 hari
  /// terakhir (chart).
  ///
  /// Nilai bersih adalah penjualan kotor
  /// dikurangi nilai retur pada hari yang sama.
  Future<Map<String, double>> penjualanPerHari({int hari = 7}) async {
    final db = await DatabaseHelper.instance.database;

    final tanggalMulai = DateTime.now().subtract(Duration(days: hari - 1));
    final awal =
        '${tanggalMulai.year.toString().padLeft(4, '0')}-${tanggalMulai.month.toString().padLeft(2, '0')}-${tanggalMulai.day.toString().padLeft(2, '0')}';

    final kotorRows = await db.rawQuery(
      '''
      SELECT substr(tanggal, 1, 10) AS tanggal,
             COALESCE(SUM(total), 0) AS total
      FROM penjualan
      WHERE tanggal >= ?
      GROUP BY substr(tanggal, 1, 10)
    ''',
      [awal],
    );

    final returRows = await db.rawQuery(
      '''
      SELECT substr(r.tanggal, 1, 10) AS tanggal,
             COALESCE(SUM(dr.subtotal), 0) AS total
      FROM retur r
      JOIN detail_retur dr ON dr.id_retur = r.id_retur
      WHERE r.tanggal >= ?
      GROUP BY substr(r.tanggal, 1, 10)
    ''',
      [awal],
    );

    final hasil = <String, double>{};

    for (final row in kotorRows) {
      hasil[row['tanggal'] as String] =
          (row['total'] as num).toDouble();
    }

    for (final row in returRows) {
      final tanggal = row['tanggal'] as String;
      final retur = (row['total'] as num).toDouble();
      hasil[tanggal] = (hasil[tanggal] ?? 0) - retur;
    }

    final tanggalTerurut = hasil.keys.toList()..sort();

    return {
      for (final tanggal in tanggalTerurut)
        tanggal: hasil[tanggal]!,
    };
  }

  String _buatNomorTransaksi() {
    final now = DateTime.now();
    final stamp = now.millisecondsSinceEpoch;
    final acak = (stamp % 900) + 100;
    return 'TRX$stamp$acak';
  }
}
