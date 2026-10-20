import 'dart:io';
import 'dart:math';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// Mengelola file foto barang di penyimpanan aplikasi.
///
/// Foto yang dipilih dari galeri disalin ke subdirektori `foto_barang`
/// di dalam direktori dokumen aplikasi, sehingga file tersimpan permanen
/// dan tidak bergantung pada lokasi sementara dari image picker.
///
/// Di database hanya disimpan path relatif (misal `foto_barang/photo_1.jpg`)
/// agar tetap valid meski direktori dokumen berubah.
class FotoService {
  static const namaDirektori = 'foto_barang';

  final Directory? _basisDirektori;

  FotoService({this._basisDirektori});

  Future<Directory> _direktoriFoto() async {
    final basis = _basisDirektori ?? await getApplicationDocumentsDirectory();

    final dir = Directory(join(basis.path, namaDirektori));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  /// Menyalin foto dari path sumber (hasil image picker) ke
  /// penyimpanan aplikasi. Mengembalikan path relatif untuk disimpan
  /// di database.
  Future<String> simpanDariSumber(String pathSumber) async {
    final fileSumber = File(pathSumber);

    if (!await fileSumber.exists()) {
      throw Exception('File foto sumber tidak ditemukan: $pathSumber');
    }

    final dir = await _direktoriFoto();
    final ekstensi = extension(pathSumber).isEmpty
        ? '.jpg'
        : extension(pathSumber);
    final nama =
        'foto_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(100000)}$ekstensi';

    final tujuan = File(join(dir.path, nama));

    await fileSumber.copy(tujuan.path);

    return join(namaDirektori, nama);
  }

  /// Menghapus file foto dari penyimpanan aplikasi.
  /// Aman dipanggil untuk path kosong atau file yang sudah hilang.
  Future<void> hapus(String? pathRelatif) async {
    if (pathRelatif == null || pathRelatif.isEmpty) return;

    final basis = _basisDirektori ?? await getApplicationDocumentsDirectory();

    final file = File(join(basis.path, pathRelatif));

    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Mengembalikan file foto jika masih ada di penyimpanan.
  Future<File?> file(String? pathRelatif) async {
    if (pathRelatif == null || pathRelatif.isEmpty) return null;

    final basis = _basisDirektori ?? await getApplicationDocumentsDirectory();

    final file = File(join(basis.path, pathRelatif));

    if (await file.exists()) {
      return file;
    }

    return null;
  }
}
