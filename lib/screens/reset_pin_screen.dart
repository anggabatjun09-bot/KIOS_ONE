import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/auth_session.dart';
import '../widgets/masukan_pin.dart';

/// Mengatur atau mengatur ulang PIN kasir.
///
/// Hanya untuk admin. PIN lama kasir
/// tidak diperlukan karena prosedur
/// ini adalah wewenang admin.
class ResetPinScreen extends StatefulWidget {
  final User akun;

  const ResetPinScreen({super.key, required this.akun});

  @override
  State<ResetPinScreen> createState() => _ResetPinScreenState();
}

enum _Tahap { pinBaru, konfirmasi }

class _ResetPinScreenState extends State<ResetPinScreen> {
  final _authService = AuthService();
  final _session = AuthSession();

  String _pinBaru = '';
  String _konfirmasi = '';
  _Tahap _tahap = _Tahap.pinBaru;
  String? _pesanError;
  bool _loading = false;

  String get _pinAktif =>
      _tahap == _Tahap.pinBaru ? _pinBaru : _konfirmasi;

  void _setPinAktif(String nilai) {
    setState(() {
      if (_tahap == _Tahap.pinBaru) {
        _pinBaru = nilai;
      } else {
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
    if (_pinBaru.length != 6) {
      setState(() => _pesanError = 'PIN harus 6 digit angka.');
      return;
    }

    setState(() {
      _tahap = _Tahap.konfirmasi;
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

    final admin = await _session.currentUser();

    if (admin == null || admin.role != Role.admin) {
      if (!mounted) return;

      setState(() => _pesanError = 'Hanya admin yang dapat mengatur PIN.');
      return;
    }

    setState(() {
      _loading = true;
      _pesanError = null;
    });

    final berhasil = await _authService.aturPinKasir(
      admin: admin,
      idUserKasir: widget.akun.idUser!,
      pinBaru: _pinBaru,
    );

    if (!mounted) return;

    setState(() => _loading = false);

    if (!berhasil) {
      setState(() {
        _pinBaru = '';
        _konfirmasi = '';
        _tahap = _Tahap.pinBaru;
        _pesanError = 'Gagal mengatur PIN. Coba lagi.';
      });

      return;
    }

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final judul = _tahap == _Tahap.pinBaru
        ? 'PIN baru untuk ${widget.akun.nama}'
        : 'Ulangi PIN baru';

    final penjelasan = _tahap == _Tahap.pinBaru
        ? 'Masukkan PIN 6 digit yang baru'
        : 'Masukkan PIN yang sama untuk konfirmasi';

    return Scaffold(
      appBar: AppBar(title: const Text('Atur PIN Kasir')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Icon(
                Icons.lock_reset_outlined,
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
                      : _tahap == _Tahap.pinBaru
                      ? _pinBaru.length == 6
                        ? _lanjut
                        : null
                      : _konfirmasi.length == 6
                        ? _simpan
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
                          _tahap == _Tahap.pinBaru
                              ? 'LANJUT'
                              : 'SIMPAN PIN',
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
