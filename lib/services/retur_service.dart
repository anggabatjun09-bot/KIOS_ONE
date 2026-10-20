import '../database/database_helper.dart';
import '../models/retur.dart';

/// Layanan retur barang.
///
/// Menyimpan retur dan memperbarui stok dalam
/// satu transaksi SQLite, sehingga tidak ada
/// data yang setengah tersimpan.
class ReturService {
  /// Menyimpan retur untuk satu transaksi penjualan.
  ///
  /// Validasi:
  /// - item tidak boleh kosong
  /// - jumlah retur tidak boleh melebihi
  ///   jumlah pembelian dikurangi retur sebelumnya
  ///
  /// Jika kondisi layak, stok barang bertambah.
  /// Jika rusak, stok siap jual tidak bertambah.
  Future<Retur> simpanRetur({
    required int idPenjualan,
    required List<ItemRetur> items,
    String? catatan,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Retur tidak boleh kosong');
    }

    final tanggal = DateTime.now().toIso8601String();
    final nomorRetur = _buatNomorRetur();

    var totalNilai = 0.0;
    for (final item in items) {
      if (item.jumlah <= 0) {
        throw ArgumentError('Jumlah retur harus lebih dari nol');
      }

      totalNilai += item.subtotal;
    }

    final db = await DatabaseHelper.instance.database;

    late Retur retur;

    await db.transaction((txn) async {
      // Transaksi penjualan asli harus ada.
      final txnRows = await txn.rawQuery(
        'SELECT id_penjualan FROM penjualan WHERE id_penjualan = ?',
        [idPenjualan],
      );

      if (txnRows.isEmpty) {
        throw StateError('Transaksi tidak ditemukan');
      }

      final idRetur = await txn.insert('retur', {
        'nomor_retur': nomorRetur,
        'id_penjualan': idPenjualan,
        'tanggal': tanggal,
        'total_nilai': totalNilai,
        'catatan': catatan,
      });

      for (final item in items) {
        // Baca detail penjualan asli.
        final detailRows = await txn.rawQuery(
          '''
          SELECT id_barang, jumlah, harga_jual
          FROM detail_penjualan
          WHERE id_detail_penjualan = ? AND id_penjualan = ?
        ''',
          [item.idDetailPenjualan, idPenjualan],
        );

        if (detailRows.isEmpty) {
          throw StateError('Item transaksi tidak ditemukan');
        }

        final idBarangAsli =
            detailRows.first['id_barang'] as int;
        final jumlahBeli = detailRows.first['jumlah'] as int;
        final hargaJualAsli =
            (detailRows.first['harga_jual'] as num).toDouble();

        // Barang harus bagian dari transaksi asli.
        if (item.idBarang != idBarangAsli) {
          throw StateError('Barang bukan bagian dari transaksi ini');
        }

        // Pastikan harga retur mengikuti harga jual asli.
        if (item.hargaSatuan != hargaJualAsli) {
          throw StateError('Harga retur tidak sesuai harga transaksi');
        }

        // Hitung sisa yang bisa dikembalikan.
        final returSebelumnya = await txn.rawQuery(
          '''
          SELECT COALESCE(SUM(jumlah), 0) AS total
          FROM detail_retur
          WHERE id_detail_penjualan = ?
        ''',
          [item.idDetailPenjualan],
        );

        final sudahRetur =
            (returSebelumnya.first['total'] as num).toInt();
        final sisa = jumlahBeli - sudahRetur;

        if (item.jumlah > sisa) {
          throw StateError(
            'Jumlah retur melebihi sisa yang dapat dikembalikan '
            '(maksimal $sisa)',
          );
        }

        // Nilai pengembalian tidak boleh melebihi
        // nilai barang yang masih dapat dikembalikan.
        if (item.subtotal > sisa * hargaJualAsli) {
          throw StateError(
            'Nilai pengembalian melebihi nilai barang '
            'yang masih dapat dikembalikan',
          );
        }

        await txn.insert('detail_retur', {
          'id_retur': idRetur,
          'id_detail_penjualan': item.idDetailPenjualan,
          'id_barang': item.idBarang,
          'jumlah': item.jumlah,
          'harga_satuan': item.hargaSatuan,
          'subtotal': item.subtotal,
          'alasan': item.alasan,
          'kondisi': item.kondisi.name,
        });

        // Stok hanya bertambah untuk barang layak jual.
        if (item.kondisi == KondisiRetur.layak) {
          await txn.rawUpdate(
            'UPDATE barang SET stok = stok + ?, updated_at = ? '
            'WHERE id_barang = ?',
            [item.jumlah, tanggal, item.idBarang],
          );
        }
      }

      retur = Retur(
        idRetur: idRetur,
        nomorRetur: nomorRetur,
        idPenjualan: idPenjualan,
        tanggal: tanggal,
        totalNilai: totalNilai,
        catatan: catatan,
      );
    });

    return retur;
  }

  /// Riwayat retur beserta nomor transaksi asli.
  Future<List<Retur>> getRiwayat({int limit = 100}) async {
    final db = await DatabaseHelper.instance.database;

    final maps = await db.rawQuery(
      '''
      SELECT retur.*, penjualan.nomor_transaksi
      FROM retur
      JOIN penjualan ON penjualan.id_penjualan = retur.id_penjualan
      ORDER BY retur.tanggal DESC, retur.id_retur DESC
      LIMIT ?
    ''',
      [limit],
    );

    return maps.map(Retur.fromMap).toList();
  }

  Future<Retur?> getById(int idRetur) async {
    final db = await DatabaseHelper.instance.database;

    final maps = await db.rawQuery(
      '''
      SELECT retur.*, penjualan.nomor_transaksi
      FROM retur
      JOIN penjualan ON penjualan.id_penjualan = retur.id_penjualan
      WHERE retur.id_retur = ?
    ''',
      [idRetur],
    );

    if (maps.isEmpty) return null;

    return Retur.fromMap(maps.first);
  }

  /// Detail item retur beserta nama dan kode barang.
  Future<List<DetailRetur>> getDetail(int idRetur) async {
    final db = await DatabaseHelper.instance.database;

    final maps = await db.rawQuery(
      '''
      SELECT detail_retur.*, barang.nama_barang, barang.kode_barang
      FROM detail_retur
      JOIN barang ON barang.id_barang = detail_retur.id_barang
      WHERE detail_retur.id_retur = ?
      ORDER BY detail_retur.id_detail_retur ASC
    ''',
      [idRetur],
    );

    return maps.map(DetailRetur.fromMap).toList();
  }

  /// Sisa jumlah yang masih dapat dikembalikan
  /// dari satu item detail penjualan.
  Future<int> sisaDapatDikembalikan(int idDetailPenjualan) async {
    final db = await DatabaseHelper.instance.database;

    final rows = await db.rawQuery(
      '''
      SELECT
        (SELECT COALESCE(SUM(jumlah), 0)
           FROM detail_penjualan
          WHERE id_detail_penjualan = ?) AS jumlah_beli,
        (SELECT COALESCE(SUM(jumlah), 0)
           FROM detail_retur
          WHERE id_detail_penjualan = ?) AS sudah_retur
    ''',
      [idDetailPenjualan, idDetailPenjualan],
    );

    if (rows.isEmpty) return 0;

    final jumlahBeli = (rows.first['jumlah_beli'] as num).toInt();
    final sudahRetur = (rows.first['sudah_retur'] as num).toInt();

    return jumlahBeli - sudahRetur;
  }

  String _buatNomorRetur() {
    // Mikrodetik agar nomor unik meskipun
    // dua retur disimpan berurutan cepat.
    return 'RT${DateTime.now().microsecondsSinceEpoch}';
  }
}
