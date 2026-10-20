import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/auth_session.dart';
import 'reset_pin_screen.dart';

/// Pengelolaan akun dan PIN.
///
/// Hanya untuk admin. Admin dapat
/// mengatur atau mengatur ulang PIN
/// kasir. PIN admin sendiri diubah
/// melalui menu ganti PIN.
class KelolaAkunScreen extends StatefulWidget {
  const KelolaAkunScreen({super.key});

  @override
  State<KelolaAkunScreen> createState() => _KelolaAkunScreenState();
}

class _KelolaAkunScreenState extends State<KelolaAkunScreen> {
  final _authService = AuthService();
  final _session = AuthSession();

  List<User> _akun = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAkun();
  }

  Future<void> _loadAkun() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final akun = await _authService.getAll();

      if (!mounted) return;

      setState(() {
        _akun = akun;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Gagal memuat akun: $e';
        _loading = false;
      });
    }
  }

  Future<void> _bukaAturPin(User akun) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ResetPinScreen(akun: akun)),
    );

    if (result == true) {
      _loadAkun();
    }
  }

  Future<void> _tambahKasir() async {
    var username = '';
    var nama = '';
    final data = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tambah akun Kasir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (value) => username = value,
              decoration: const InputDecoration(labelText: 'Nama pengguna'),
              textCapitalization: TextCapitalization.none,
            ),
            TextField(
              onChanged: (value) => nama = value,
              decoration: const InputDecoration(labelText: 'Nama Kasir'),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('BATAL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, (username, nama)),
            child: const Text('BUAT AKUN'),
          ),
        ],
      ),
    );

    if (data == null) return;
    if (data.$1.trim().isEmpty || data.$2.trim().isEmpty) {
      _snackbar('Nama pengguna dan nama Kasir harus diisi.');
      return;
    }

    try {
      final admin = await _session.currentUser();
      if (admin == null || admin.role != Role.admin) {
        _snackbar('Hanya Admin yang dapat membuat akun Kasir.');
        return;
      }

      final akun = await _authService.buatAkunKasir(
        admin: admin,
        username: data.$1,
        nama: data.$2,
      );
      if (akun == null) {
        _snackbar('Nama pengguna sudah dipakai atau akun tidak valid.');
        return;
      }

      if (!mounted) return;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => ResetPinScreen(akun: akun)),
      );
      if (!mounted) return;
      await _loadAkun();
    } on DatabaseException {
      _snackbar('Gagal membuat akun Kasir. Silakan coba lagi.');
    }
  }

  void _snackbar(String pesan) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengguna'),
        actions: [
          IconButton(
            tooltip: 'Tambah akun Kasir',
            onPressed: _tambahKasir,
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAkun,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : _akun.isEmpty
            ? const Center(child: Text('Belum ada akun.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _akun.length,
                itemBuilder: (context, index) {
                  final akun = _akun[index];

                  return _buildItem(akun);
                },
              ),
      ),
    );
  }

  Widget _buildItem(User akun) {
    final adalahAdmin = akun.role == Role.admin;
    final punyaPin = akun.pinHash != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            adalahAdmin
                ? Icons.admin_panel_settings_outlined
                : Icons.point_of_sale_outlined,
          ),
        ),
        title: Text(
          akun.nama,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${akun.username} · ${akun.role.name} · '
          '${punyaPin ? 'PIN aktif' : 'PIN belum ditetapkan'}',
        ),
        trailing: Icon(
          punyaPin ? Icons.check_circle_outline : Icons.lock_open_outlined,
          color: punyaPin ? Colors.green : Theme.of(context).colorScheme.error,
        ),
        onTap: () {
          if (adalahAdmin) {
            _snackbar('PIN admin diganti melalui menu Ganti PIN.');

            return;
          }

          _bukaAturPin(akun);
        },
      ),
    );
  }
}
