import '../database/database_helper.dart';
import '../models/stok_masuk.dart';

class StokMasukService {
  /// Mencatat stok masuk dan menambah stok barang
  /// dalam satu transaksi SQLite.
  Future<StokMasuk> tambah({
    required int idBarang,
    required int jumlah,
    required double hargaBeli,
    String? keterangan,
  }) async {
    if (jumlah <= 0) {
      throw ArgumentError('Jumlah stok masuk harus lebih dari 0');
    }

    if (!hargaBeli.isFinite || hargaBeli < 0) {
      throw ArgumentError('Harga beli harus bernilai valid dan tidak negatif');
    }

    final db = await DatabaseHelper.instance.database;
    final tanggal = DateTime.now().toIso8601String();
    final subtotal = jumlah * hargaBeli;

    late StokMasuk record;

    await db.transaction((txn) async {
      final id = await txn.insert('stok_masuk', {
        'id_barang': idBarang,
        'tanggal': tanggal,
        'jumlah': jumlah,
        'harga_beli': hargaBeli,
        'subtotal': subtotal,
        'keterangan': keterangan,
      });

      // Tambah stok barang.
      await txn.rawUpdate(
        'UPDATE barang SET stok = stok + ?, updated_at = ? WHERE id_barang = ?',
        [jumlah, tanggal, idBarang],
      );

      record = StokMasuk(
        idStokMasuk: id,
        idBarang: idBarang,
        tanggal: tanggal,
        jumlah: jumlah,
        hargaBeli: hargaBeli,
        subtotal: subtotal,
        keterangan: keterangan,
      );
    });

    return record;
  }

  Future<List<StokMasuk>> getRiwayat({int limit = 50}) async {
    final db = await DatabaseHelper.instance.database;

    final maps = await db.rawQuery(
      '''
      SELECT stok_masuk.*, barang.nama_barang
      FROM stok_masuk
      JOIN barang ON barang.id_barang = stok_masuk.id_barang
      ORDER BY stok_masuk.tanggal DESC, stok_masuk.id_stok_masuk DESC
      LIMIT ?
    ''',
      [limit],
    );

    return maps.map(StokMasuk.fromMap).toList();
  }
}
