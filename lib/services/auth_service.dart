import 'package:meta/meta.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/user.dart';
import 'pin_util.dart';

/// Jenis kegagalan login.
enum LoginKesalahan {
  pinTidakValid,
  pinSalah,
  roleTidakCocok,
  pinBelumDitetapkan,
  terlaluBanyakPercobaan,
  databaseError,
}

/// Hasil percobaan login.
class LoginResult {
  final User? user;
  final LoginKesalahan? kesalahan;

  /// Sisa waktu jeda setelah terlalu
  /// banyak percobaan salah.
  final Duration? jedaSampai;

  /// Sisa percobaan PIN sebelum
  /// akun dijeda.
  final int? sisaPercobaan;

  const LoginResult.berhasil(this.user)
    : kesalahan = null,
      jedaSampai = null,
      sisaPercobaan = null;

  const LoginResult.gagal(this.kesalahan, {this.jedaSampai, this.sisaPercobaan})
    : user = null;

  bool get berhasil => user != null;
}

/// Autentikasi pengguna terhadap SQLite
/// menggunakan PIN numerik 6 digit.
///
/// PIN disimpan sebagai hash PBKDF2 dengan
/// salt unik per akun. PIN tidak pernah
/// disimpan sebagai teks biasa.
class AuthService {
  /// Maksimum percobaan PIN salah
  /// berturut-turut sebelum jeda.
  static const _maksimumPercobaan = 5;

  /// Lama jeda setelah percobaan
  /// habis.
  static const _durasiJeda = Duration(seconds: 30);

  static int _jumlahSalah = 0;
  static DateTime? _sampaiWaktu;

  /// Menghapus pembatasan percobaan.
  /// Hanya untuk pengujian.
  @visibleForTesting
  static void resetPembatasan() {
    _jumlahSalah = 0;
    _sampaiWaktu = null;
  }

  /// Memeriksa apakah penyiapan PIN awal
  /// diperlukan untuk role tertentu.
  ///
  /// Penyiapan awal dibuka selama belum ada
  /// akun yang mempunyai PIN. Setelah itu,
  /// PIN kasir hanya dapat ditetapkan oleh
  /// admin. PIN admin dapat dipulihkan
  /// selama belum ada akun admin ber-PIN.
  Future<bool> perluPenyiapanPin({required Role role}) async {
    final db = await DatabaseHelper.instance.database;

    final berPin = await db.query('users', where: 'pin_hash IS NOT NULL');

    if (berPin.isEmpty) {
      // Penyiapan awal: belum ada akun
      // dengan PIN. Pemilik dapat
      // menetapkan PIN Admin dan PIN Kasir.
      return true;
    }

    if (role == Role.admin) {
      // Pemulihan PIN admin: hanya jika
      // belum ada akun admin ber-PIN.
      return !berPin.any((row) => row['role'] == Role.admin.name);
    }

    // PIN kasir ditetapkan oleh admin.
    return false;
  }

  /// Menyiapkan PIN awal untuk role.
  ///
  /// Hanya berlaku saat penyiapan awal atau
  /// pemulihan admin. Akun dan PIN yang
  /// sudah ada tidak pernah ditimpa.
  Future<bool> siapkanPinAwal({required Role role, required String pin}) async {
    if (!pinValid(pin)) return false;
    if (!await perluPenyiapanPin(role: role)) return false;

    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'users',
      where: 'role = ?',
      whereArgs: [role.name],
    );

    final pinHash = hashPinBaru(pin);

    if (rows.isEmpty) {
      // Belum ada akun untuk role ini.
      // Buat akun baru dengan PIN.
      await db.insert('users', {
        'username': role.name,
        'password': '',
        'nama': role == Role.admin ? 'Administrator' : 'Kasir',
        'role': role.name,
        'pin_hash': pinHash,
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    }

    // Akun sudah ada. Hanya akun tanpa
    // PIN yang ditetapkan. PIN yang
    // sudah ada tidak ditimpa.
    final tanpaPin = rows.where((row) => row['pin_hash'] == null).toList();

    if (tanpaPin.isEmpty) return false;

    await db.update(
      'users',
      {'pin_hash': pinHash},
      where: 'id_user = ?',
      whereArgs: [tanpaPin.first['id_user']],
    );

    return true;
  }

  /// Admin membuat akun Kasir baru tanpa PIN.
  ///
  /// PIN harus ditetapkan melalui alur kelola akun setelah akun dibuat.
  Future<User?> buatAkunKasir({
    required User admin,
    required String username,
    required String nama,
  }) async {
    if (admin.role != Role.admin) return null;

    final usernameBersih = username.trim();
    final namaBersih = nama.trim();
    if (usernameBersih.isEmpty || namaBersih.isEmpty) return null;

    final db = await DatabaseHelper.instance.database;
    final akunDenganUsername = await db.query(
      'users',
      columns: ['id_user'],
      where: 'username = ?',
      whereArgs: [usernameBersih],
      limit: 1,
    );
    if (akunDenganUsername.isNotEmpty) return null;

    final createdAt = DateTime.now().toIso8601String();
    final idUser = await db.insert('users', {
      'username': usernameBersih,
      'password': '',
      'nama': namaBersih,
      'role': Role.kasir.name,
      'pin_hash': null,
      'created_at': createdAt,
    });

    return User(
      idUser: idUser,
      username: usernameBersih,
      nama: namaBersih,
      role: Role.kasir,
      createdAt: createdAt,
    );
  }

  /// Login dengan PIN untuk role tertentu.
  ///
  /// PIN hanya diverifikasi terhadap akun
  /// dengan role yang dipilih, sehingga
  /// PIN admin tidak dapat masuk sebagai
  /// kasir dan sebaliknya.
  Future<LoginResult> login({required String pin, required Role role}) async {
    if (!pinValid(pin)) {
      return const LoginResult.gagal(LoginKesalahan.pinTidakValid);
    }

    final sekarang = DateTime.now();
    final sampai = _sampaiWaktu;

    if (sampai != null) {
      if (sekarang.isBefore(sampai)) {
        return LoginResult.gagal(
          LoginKesalahan.terlaluBanyakPercobaan,
          jedaSampai: sampai.difference(sekarang),
        );
      }

      // Masa jeda sudah berakhir.
      _jumlahSalah = 0;
      _sampaiWaktu = null;
    }

    late final List<Map<String, Object?>> rows;
    try {
      final db = await DatabaseHelper.instance.database;
      rows = await db.query('users', where: 'role = ?', whereArgs: [role.name]);
    } on DatabaseException {
      return const LoginResult.gagal(LoginKesalahan.databaseError);
    }

    if (rows.isEmpty) {
      return const LoginResult.gagal(LoginKesalahan.roleTidakCocok);
    }

    final denganPin = rows.where((row) => row['pin_hash'] != null).toList();

    for (final row in denganPin) {
      if (verifikasiPin(pin, row['pin_hash'] as String)) {
        _jumlahSalah = 0;
        _sampaiWaktu = null;

        return LoginResult.berhasil(User.fromMap(row));
      }
    }

    // Tidak ada PIN yang cocok.
    // Sisa percobaan dihitung sebelum
    // penghitung bertambah sehingga
    // percobaan terakhir melaporkan
    // sisa 1.
    final sisa = _maksimumPercobaan - _jumlahSalah;
    _jumlahSalah++;

    if (_jumlahSalah >= _maksimumPercobaan) {
      _sampaiWaktu = DateTime.now().add(_durasiJeda);
    }

    if (denganPin.isEmpty) {
      return const LoginResult.gagal(LoginKesalahan.pinBelumDitetapkan);
    }

    return LoginResult.gagal(LoginKesalahan.pinSalah, sisaPercobaan: sisa);
  }

  /// Mengganti PIN pengguna yang sedang
  /// login. PIN lama harus diverifikasi.
  Future<bool> gantiPin({
    required int idUser,
    required String pinLama,
    required String pinBaru,
  }) async {
    if (!pinValid(pinBaru)) return false;

    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'users',
      where: 'id_user = ?',
      whereArgs: [idUser],
    );

    if (rows.isEmpty) return false;

    final pinHash = rows.first['pin_hash'] as String?;

    if (pinHash == null) return false;
    if (!verifikasiPin(pinLama, pinHash)) return false;

    await db.update(
      'users',
      {'pin_hash': hashPinBaru(pinBaru)},
      where: 'id_user = ?',
      whereArgs: [idUser],
    );

    return true;
  }

  /// Admin menetapkan atau mengatur ulang
  /// PIN kasir.
  ///
  /// PIN lama kasir tidak diperlukan karena
  /// prosedur ini adalah wewenang admin.
  /// PIN admin tidak dapat diatur melalui
  /// metode ini.
  Future<bool> aturPinKasir({
    required User admin,
    required int idUserKasir,
    required String pinBaru,
  }) async {
    // Hanya admin yang berwenang.
    if (admin.role != Role.admin) return false;
    if (!pinValid(pinBaru)) return false;

    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'users',
      where: 'id_user = ?',
      whereArgs: [idUserKasir],
    );

    if (rows.isEmpty) return false;

    final target = rows.first;

    // PIN admin hanya diubah melalui
    // verifikasi PIN lama (ganti PIN).
    if (target['role'] == Role.admin.name) return false;

    await db.update(
      'users',
      {'pin_hash': hashPinBaru(pinBaru)},
      where: 'id_user = ?',
      whereArgs: [idUserKasir],
    );

    return true;
  }

  Future<User?> getById(int idUser) async {
    final db = await DatabaseHelper.instance.database;

    final rows = await db.query(
      'users',
      where: 'id_user = ?',
      whereArgs: [idUser],
    );

    if (rows.isEmpty) return null;

    return User.fromMap(rows.first);
  }

  Future<List<User>> getAll() async {
    final db = await DatabaseHelper.instance.database;

    final rows = await db.query('users', orderBy: 'nama ASC');

    return rows.map(User.fromMap).toList();
  }
}
