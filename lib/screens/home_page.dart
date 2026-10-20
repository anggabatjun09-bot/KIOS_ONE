import 'package:flutter/material.dart';

import 'barang_screen.dart';
import 'dashboard_screen.dart';
import 'kasir_screen.dart';
import 'kategori_screen.dart';
import 'profile_screen.dart';
import 'riwayat_transaksi_screen.dart';
import 'role_pilih_screen.dart';
import '../models/user.dart';
import '../services/auth_session.dart';
import '../utils/role_guard.dart';

/// Halaman utama dengan navigasi bawah.
///
/// Daftar halaman dan menu cepat
/// disesuaikan dengan role pengguna.
/// Kasir tidak mendapatkan halaman
/// yang tidak diizinkan.
class HomePage extends StatefulWidget {
  final Role role;
  final User? user;

  const HomePage({super.key, required this.role, this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  final dashboardKey = GlobalKey<DashboardScreenState>();

  late final List<Widget> pages;
  late final List<String> titles;

  int? _idUserAktif;

  bool get _isAdmin => widget.role == Role.admin;

  @override
  void initState() {
    super.initState();
    _idUserAktif = widget.user?.idUser;
    _siapkanHalaman();

    if (widget.user == null) {
      _muatUserAktif();
    }
  }

  Future<void> _muatUserAktif() async {
    final user = await AuthSession().currentUser();

    if (!mounted || user == null) return;

    setState(() {
      _idUserAktif = user.idUser;
      _siapkanHalaman();
    });
  }

  void _siapkanHalaman() {
    pages = [
      DashboardScreen(
        key: dashboardKey,
        role: widget.role,
        idUser: _idUserAktif,
      ),

      // Kasir melihat barang tanpa
      // kemampuan menambah/mengedit/menghapus.
      BarangScreen(readOnly: !_isAdmin),
      KasirScreen(idUser: _idUserAktif),

      if (_isAdmin) ProfileScreen(),

      if (!_isAdmin) RiwayatTransaksiScreen(),
    ];

    titles = _isAdmin
        ? ['Dashboard', 'Barang', 'Kasir', 'Profil']
        : ['Dashboard', 'Barang', 'Kasir', 'Riwayat'];
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: Text('Keluar dari akun ${widget.role.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('KELUAR'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Hapus session aktif.
    await AuthSession().logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RolePilihScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (selectedIndex == 1 && _isAdmin)
            IconButton(
              tooltip: 'Kelola Kategori',
              onPressed: () => bukaHalaman(
                context,
                role: widget.role,
                minimalRole: Role.admin,
                halaman: KategoriScreen(),
              ),
              icon: const Icon(Icons.category_outlined),
            ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),

      body: IndexedStack(index: selectedIndex, children: pages),

      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });

          // Muat ulang dashboard saat dibuka kembali
          // agar mencerminkan data terbaru.
          if (index == 0) {
            dashboardKey.currentState?.refresh();
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: _isAdmin ? 'Barang' : 'Barang',
          ),
          const NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Kasir',
          ),
          if (!_isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Riwayat',
            ),
          if (_isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
        ],
      ),
    );
  }
}
