import '../database/database_helper.dart';
import '../models/barang.dart';
import 'foto_service.dart';

class BarangService {
  final FotoService fotoService;

  BarangService({FotoService? fotoService})
    : fotoService = fotoService ?? FotoService();

  Future<List<Barang>> getAll({String? keyword}) async {
    final db = await DatabaseHelper.instance.database;

    final where = keyword != null && keyword.trim().isNotEmpty
        ? "WHERE kode_barang LIKE ? OR nama_barang LIKE ?"
        : '';

    final args = keyword != null && keyword.trim().isNotEmpty
        ? ['%${keyword.trim()}%', '%${keyword.trim()}%']
        : [];

    final maps = await db.rawQuery(
      'SELECT * FROM barang $where ORDER BY nama_barang ASC',
      args,
    );

    return maps.map(Barang.fromMap).toList();
  }

  Future<Barang?> getById(int id) async {
    final db = await DatabaseHelper.instance.database;

    final maps = await db.query(
      'barang',
      where: 'id_barang = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    return Barang.fromMap(maps.first);
  }

  Future<int> insert(Barang barang) async {
    _validasi(barang);
    final db = await DatabaseHelper.instance.database;

    return db.insert('barang', barang.toMap());
  }

  Future<int> update(Barang barang) async {
    if (barang.idBarang == null || barang.idBarang! <= 0) {
      throw ArgumentError('ID barang tidak valid');
    }

    _validasi(barang);
    final db = await DatabaseHelper.instance.database;

    return db.update(
      'barang',
      barang.toMap(),
      where: 'id_barang = ?',
      whereArgs: [barang.idBarang],
    );
  }

  /// Menghapus barang beserta file fotonya.
  Future<int> delete(int id) async {
    final db = await DatabaseHelper.instance.database;

    final barang = await getById(id);

    final jumlahDihapus = await db.delete(
      'barang',
      where: 'id_barang = ?',
      whereArgs: [id],
    );

    if (jumlahDihapus > 0 && barang?.foto != null) {
      await fotoService.hapus(barang!.foto);
    }

    return jumlahDihapus;
  }

  void _validasi(Barang barang) {
    if (barang.kodeBarang.trim().isEmpty ||
        barang.namaBarang.trim().isEmpty ||
        barang.satuan.trim().isEmpty) {
      throw ArgumentError('Kode, nama, dan satuan barang wajib diisi');
    }

    if (!barang.hargaBeli.isFinite ||
        barang.hargaBeli < 0 ||
        !barang.hargaJual.isFinite ||
        barang.hargaJual < 0) {
      throw ArgumentError('Harga barang harus valid dan tidak negatif');
    }

    if (barang.stok < 0 || barang.stokMinimum < 0) {
      throw ArgumentError('Stok dan stok minimum tidak boleh negatif');
    }
  }
}
