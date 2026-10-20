import '../database/database_helper.dart';
import '../models/pengeluaran.dart';

class PengeluaranService {
  Future<int> insert(Pengeluaran pengeluaran) async {
    if (pengeluaran.kategori.trim().isEmpty ||
        !pengeluaran.nominal.isFinite ||
        pengeluaran.nominal <= 0) {
      throw ArgumentError(
        'Kategori wajib diisi dan nominal harus lebih dari 0',
      );
    }

    final db = await DatabaseHelper.instance.database;

    return db.insert('pengeluaran', pengeluaran.toMap());
  }

  Future<List<Pengeluaran>> getAll({int limit = 200}) async {
    final db = await DatabaseHelper.instance.database;

    final maps = await db.query(
      'pengeluaran',
      orderBy: 'tanggal DESC, id_pengeluaran DESC',
      limit: limit,
    );

    return maps.map(Pengeluaran.fromMap).toList();
  }

  Future<double> totalPeriode({
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

    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(nominal), 0) AS total FROM pengeluaran $where',
      args,
    );

    return (rows.first['total'] as num).toDouble();
  }

  Future<int> delete(int id) async {
    final db = await DatabaseHelper.instance.database;

    return db.delete(
      'pengeluaran',
      where: 'id_pengeluaran = ?',
      whereArgs: [id],
    );
  }
}
