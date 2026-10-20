import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/auth_session.dart';
import '../widgets/masukan_pin.dart';
import 'home_page.dart';
import 'setup_pin_screen.dart';

/// Layar login dengan PIN numerik.
///
/// PIN dimasukkan melalui keypad angka
/// dan tidak pernah ditampilkan sebagai
/// teks biasa. Username dan password
/// tidak digunakan pada layar ini.
class LoginScreen extends StatefulWidget {
  final Role role;

  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _session = AuthSession();

  String _pin = '';
  String? _pesanError;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _periksaPenyiapanPin();
  }

  /// Membuka penyiapan PIN awal jika
  /// akun belum mempunyai PIN.
  Future<void> _periksaPenyiapanPin() async {
    late final bool perlu;
    try {
      perlu = await _authService.perluPenyiapanPin(role: widget.role);
    } on DatabaseException {
      if (!mounted) return;
      setState(() {
        _pesanError = 'Data tidak dapat diakses. Silakan coba lagi.';
      });
      return;
    }

    if (!mounted) return;

    if (perlu) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SetupPinScreen(role: widget.role)),
      );
    }
  }

  void _tekanDigit(String digit) {
    if (_pin.length >= 6) return;

    setState(() {
      _pin += digit;
      _pesanError = null;
    });
  }

  void _hapusSatuDigit() {
    if (_pin.isEmpty) return;

    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _pesanError = null;
    });
  }

  void _hapusSemua() {
    setState(() {
      _pin = '';
      _pesanError = null;
    });
  }

  Future<void> _masuk() async {
    if (_pin.length != 6) {
      setState(() => _pesanError = 'PIN harus 6 digit angka.');
      return;
    }

    setState(() {
      _loading = true;
      _pesanError = null;
    });

    final result = await _authService.login(pin: _pin, role: widget.role);

    if (!mounted) return;

    setState(() => _loading = false);

    if (!result.berhasil) {
      setState(() {
        _pin = '';
        _pesanError = _pesanKesalahan(result);
      });

      return;
    }

    await _session.login(result.user!, tetapLogin: true);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomePage(role: result.user!.role, user: result.user!),
      ),
    );
  }

  String _pesanKesalahan(LoginResult result) {
    switch (result.kesalahan ?? LoginKesalahan.pinSalah) {
      case LoginKesalahan.pinTidakValid:
        return 'PIN harus 6 digit angka.';
      case LoginKesalahan.pinSalah:
        final sisa = result.sisaPercobaan;

        if (sisa != null && sisa > 0) {
          return 'PIN salah. Sisa percobaan: $sisa.';
        }

        return 'PIN salah.';
      case LoginKesalahan.roleTidakCocok:
        return widget.role == Role.kasir
            ? 'Belum ada akun Kasir. Masuk sebagai Admin, lalu buka '
                  'Pengguna > Tambah Kasir.'
            : 'Belum ada akun Admin yang terdaftar.';
      case LoginKesalahan.pinBelumDitetapkan:
        return widget.role == Role.kasir
            ? 'PIN belum ditetapkan. Masuk sebagai Admin, lalu buka '
                  'Pengguna untuk mengatur PIN Kasir.'
            : 'PIN Admin belum ditetapkan. Hubungi administrator.';
      case LoginKesalahan.terlaluBanyakPercobaan:
        final jeda = result.jedaSampai;
        final detik = jeda == null ? 30 : jeda.inSeconds + 1;

        return 'Terlalu banyak percobaan salah. '
            'Coba lagi dalam $detik detik.';
      case LoginKesalahan.databaseError:
        return 'Data tidak dapat diakses. Silakan coba lagi.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelRole = widget.role == Role.admin ? 'Admin' : 'Kasir';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Masuk sebagai $labelRole'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Icon(
                widget.role == Role.admin
                    ? Icons.admin_panel_settings_outlined
                    : Icons.point_of_sale_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Masukkan PIN $labelRole',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              IndikatorPin(jumlah: _pin.length),
              const SizedBox(height: 12),
              SizedBox(
                height: 20,
                child: Text(
                  _pesanError ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: KeypadPin(
                  onDigit: _tekanDigit,
                  onHapusSatu: _hapusSatuDigit,
                  onHapusSemua: _hapusSemua,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _masuk,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'MASUK',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
