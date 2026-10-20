import '../database/database_helper.dart';
import '../models/kategori.dart';

class KategoriService {
  Future<List<Kategori>> getAll() async {
    final db = await DatabaseHelper.instance.database;

    final maps = await db.query('kategori', orderBy: 'nama_kategori ASC');

    return maps.map(Kategori.fromMap).toList();
  }

  Future<int> insert(Kategori kategori) async {
    final db = await DatabaseHelper.instance.database;

    return db.insert('kategori', kategori.toMap());
  }

  Future<int> update(Kategori kategori) async {
    final db = await DatabaseHelper.instance.database;

    return db.update(
      'kategori',
      kategori.toMap(),
      where: 'id_kategori = ?',
      whereArgs: [kategori.idKategori],
    );
  }

  /// Menghapus kategori. Gagal jika masih dipakai barang
  /// (foreign key).
  Future<int> delete(int id) async {
    final db = await DatabaseHelper.instance.database;

    return db.delete('kategori', where: 'id_kategori = ?', whereArgs: [id]);
  }
}
