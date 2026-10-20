import '../database/database_helper.dart';
import '../models/pemasukan.dart';

class PemasukanService {
  Future<int> insert(Pemasukan pemasukan) async {
    if (pemasukan.sumber.trim().isEmpty ||
        !pemasukan.nominal.isFinite ||
        pemasukan.nominal <= 0) {
      throw ArgumentError('Sumber wajib diisi dan nominal harus lebih dari 0');
    }

    final db = await DatabaseHelper.instance.database;

    return db.insert('pemasukan', pemasukan.toMap());
  }

  Future<List<Pemasukan>> getAll({int limit = 200}) async {
    final db = await DatabaseHelper.instance.database;

    final maps = await db.query(
      'pemasukan',
      orderBy: 'tanggal DESC, id_pemasukan DESC',
      limit: limit,
    );

    return maps.map(Pemasukan.fromMap).toList();
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
      'SELECT COALESCE(SUM(nominal), 0) AS total FROM pemasukan $where',
      args,
    );

    return (rows.first['total'] as num).toDouble();
  }

  Future<int> delete(int id) async {
    final db = await DatabaseHelper.instance.database;

    return db.delete('pemasukan', where: 'id_pemasukan = ?', whereArgs: [id]);
  }
}
