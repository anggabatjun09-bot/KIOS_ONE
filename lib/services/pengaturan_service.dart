import '../database/database_helper.dart';
import '../models/pengaturan.dart';

class PengaturanService {
  Future<Pengaturan?> get() async {
    final db = await DatabaseHelper.instance.database;

    final maps = await db.query('pengaturan', limit: 1);

    if (maps.isEmpty) return null;

    return Pengaturan.fromMap(maps.first);
  }

  Future<void> update(Pengaturan pengaturan) async {
    final db = await DatabaseHelper.instance.database;

    await db.update(
      'pengaturan',
      pengaturan.toMap(),
      where: 'id_pengaturan = ?',
      whereArgs: [pengaturan.idPengaturan],
    );
  }
}
