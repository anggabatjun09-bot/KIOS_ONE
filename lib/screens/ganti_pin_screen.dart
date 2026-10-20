import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/auth_session.dart';
import '../widgets/masukan_pin.dart';

/// Mengganti PIN pengguna yang sedang login.
///
/// PIN lama diverifikasi sebelum PIN
/// baru disimpan. PIN lama tidak
/// pernah ditampilkan.
class GantiPinScreen extends StatefulWidget {
  const GantiPinScreen({super.key});

  @override
  State<GantiPinScreen> createState() => _GantiPinScreenState();
}

enum _Tahap { pinLama, pinBaru, konfirmasi }

class _GantiPinScreenState extends State<GantiPinScreen> {
  final _authService = AuthService();
  final _session = AuthSession();

  String _pinLama = '';
  String _pinBaru = '';
  String _konfirmasi = '';
  _Tahap _tahap = _Tahap.pinLama;
  String? _pesanError;
  bool _loading = false;

  String get _pinAktif {
    switch (_tahap) {
      case _Tahap.pinLama:
        return _pinLama;
      case _Tahap.pinBaru:
        return _pinBaru;
      case _Tahap.konfirmasi:
        return _konfirmasi;
    }
  }

  void _setPinAktif(String nilai) {
    setState(() {
      switch (_tahap) {
        case _Tahap.pinLama:
          _pinLama = nilai;
        case _Tahap.pinBaru:
          _pinBaru = nilai;
        case _Tahap.konfirmasi:
          _konfirmasi = nilai;
      }

      _pesanError = null;
    });
  }

  void _tekanDigit(String digit) {
    if (_pinAktif.length >= 6) return;

    _setPinAktif(_pinAktif + digit);
  }

  void _hapusSatuDigit() {
    if (_pinAktif.isEmpty) return;

    _setPinAktif(_pinAktif.substring(0, _pinAktif.length - 1));
  }

  void _hapusSemua() => _setPinAktif('');

  Future<void> _lanjut() async {
    if (_pinAktif.length != 6) {
      setState(() => _pesanError = 'PIN harus 6 digit angka.');
      return;
    }

    setState(() {
      switch (_tahap) {
        case _Tahap.pinLama:
          _tahap = _Tahap.pinBaru;
        case _Tahap.pinBaru:
          _tahap = _Tahap.konfirmasi;
        case _Tahap.konfirmasi:
          break;
      }

      _pesanError = null;
    });
  }

  Future<void> _simpan() async {
    if (_pinBaru.length != 6 || _konfirmasi.length != 6) {
      setState(() => _pesanError = 'PIN harus 6 digit angka.');
      return;
    }

    if (_pinBaru != _konfirmasi) {
      setState(() => _pesanError = 'Konfirmasi PIN tidak sama.');
      return;
    }

    final user = await _session.currentUser();

    if (user == null || user.idUser == null) {
      if (!mounted) return;

      setState(() => _pesanError = 'Session tidak ditemukan. Silakan login ulang.');
      return;
    }

    setState(() {
      _loading = true;
      _pesanError = null;
    });

    final berhasil = await _authService.gantiPin(
      idUser: user.idUser!,
      pinLama: _pinLama,
      pinBaru: _pinBaru,
    );

    if (!mounted) return;

    setState(() => _loading = false);

    if (!berhasil) {
      setState(() {
        _pinLama = '';
        _pinBaru = '';
        _konfirmasi = '';
        _tahap = _Tahap.pinLama;
        _pesanError = 'PIN lama salah atau PIN baru tidak valid.';
      });

      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN berhasil diganti.')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final judul = switch (_tahap) {
      _Tahap.pinLama => 'Masukkan PIN lama',
      _Tahap.pinBaru => 'Masukkan PIN baru',
      _Tahap.konfirmasi => 'Ulangi PIN baru',
    };

    final penjelasan = switch (_tahap) {
      _Tahap.pinLama => 'Verifikasi PIN yang sedang digunakan',
      _Tahap.pinBaru => 'Masukkan PIN 6 digit yang baru',
      _Tahap.konfirmasi => 'Masukkan PIN yang sama untuk konfirmasi',
    };

    final labelTombol = switch (_tahap) {
      _Tahap.pinLama => 'LANJUT',
      _Tahap.pinBaru => 'LANJUT',
      _Tahap.konfirmasi => 'SIMPAN PIN',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Ganti PIN')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Icon(
                Icons.lock_outline,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                judul,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                penjelasan,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              IndikatorPin(jumlah: _pinAktif.length),
              const SizedBox(height: 12),
              SizedBox(
                height: 20,
                child: Text(
                  _pesanError ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
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
                  onPressed: _loading
                      ? null
                      : _pinAktif.length == 6
                        ? _tahap == _Tahap.konfirmasi
                          ? _simpan
                          : _lanjut
                        : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          labelTombol,
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
