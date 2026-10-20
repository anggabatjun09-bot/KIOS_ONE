import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import 'auth_service.dart';

/// Session pengguna aktif.
///
/// Session TIDAK pernah menyimpan password.
/// Role dibaca dari database saat session
/// dipulihkan, sehingga role tidak dapat
/// diubah hanya dengan mengedit
/// penyimpanan lokal.
class AuthSession {
  static const _kIdUser = 'session_id_user';
  static const _kTetapLogin = 'session_tetap_login';

  final AuthService _authService = AuthService();

  /// Pengguna yang login di memori.
  User? _pengguna;

  /// Menyimpan session login.
  ///
  /// Password tidak disimpan di mana pun.
  Future<void> login(User user, {bool tetapLogin = true}) async {
    _pengguna = user;

    if (tetapLogin) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kIdUser, user.idUser!);
      await prefs.setBool(_kTetapLogin, true);
    }
  }

  /// Memulihkan session.
  ///
  /// Data pengguna (termasuk role) selalu
  /// diambil dari database.
  Future<User?> currentUser() async {
    if (_pengguna != null) {
      final fresh = await _authService.getById(_pengguna!.idUser!);

      if (fresh != null) {
        _pengguna = fresh;
        return fresh;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final idUser = prefs.getInt(_kIdUser);

    if (idUser == null) {
      return null;
    }

    _pengguna = await _authService.getById(idUser);

    return _pengguna;
  }

  /// Menghapus session aktif.
  Future<void> logout() async {
    _pengguna = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kIdUser);
    await prefs.remove(_kTetapLogin);
  }
}
