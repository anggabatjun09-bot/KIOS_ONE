import 'dart:async';

import 'package:flutter/material.dart';

import '../models/barang.dart';
import '../models/penjualan.dart';
import '../models/user.dart';
import '../screens/barang_screen.dart';
import '../screens/ganti_pin_screen.dart';
import '../screens/kasir_screen.dart';
import '../screens/kategori_screen.dart';
import '../screens/kelola_akun_screen.dart';
import '../screens/laporan_screen.dart';
import '../screens/pemasukan_screen.dart';
import '../screens/pengeluaran_screen.dart';
import '../screens/retur_screen.dart';
import '../screens/riwayat_transaksi_screen.dart';
import '../screens/role_pilih_screen.dart';
import '../screens/stok_masuk_screen.dart';
import '../services/auth_session.dart';
import '../services/dashboard_service.dart';
import '../utils/kios_utils.dart';
import '../utils/role_guard.dart';

class DashboardScreen extends StatefulWidget {
  final DashboardService dashboardService;
  final Role role;
  final int? idUser;

  DashboardScreen({
    super.key,
    DashboardService? dashboardService,
    required this.role,
    this.idUser,
  }) : dashboardService = dashboardService ?? DashboardService();

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  DashboardRingkasan? _ringkasan;
  List<Barang> _stokMenipis = [];
  List<Penjualan> _transaksi = [];
  bool _loading = true;
  String _error = '';

  /// Tanggal lokal terakhir yang sudah
  /// dimuat ke ringkasan.
  String _tanggalTerakhir = '';

  /// Pemeriksa pergantian tanggal.
  /// Ringan: satu callback per menit,
  /// hanya berfungsi saat tanggal berbeda.
  Timer? _timerPergantianTanggal;

  bool get _isAdmin => widget.role == Role.admin;

  @override
  void initState() {
    super.initState();

    _tanggalTerakhir = tanggalHariIni();
    WidgetsBinding.instance.addObserver(this);

    // Saat aplikasi tetap terbuka melewati
    // tengah malam, ringkasan harian
    // berganti otomatis ke tanggal baru.
    _timerPergantianTanggal = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _periksaPergantianTanggal(),
    );

    _loadData();
  }

  @override
  void dispose() {
    _timerPergantianTanggal?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Data ikut benar ketika aplikasi
    // dibuka kembali dari latar belakang.
    if (state == AppLifecycleState.resumed) {
      _periksaPergantianTanggal();
    }
  }

  /// Memuat ulang ringkasan bila tanggal
  /// lokal sudah berganti (tengah malam).
  void _periksaPergantianTanggal() {
    if (!mounted) return;

    final tanggalSekarang = tanggalHariIni();

    if (tanggalSekarang == _tanggalTerakhir) return;

    _tanggalTerakhir = tanggalSekarang;
    _loadData();
  }

  /// Memuat ulang data dashboard.
  Future<void> refresh() => _loadData();

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final ringkasan = await widget.dashboardService.ringkasanHariIni();
      final stokMenipis = await widget.dashboardService.stokPerluDiperhatikan();
      final transaksi = await widget.dashboardService.transaksiTerbaru();

      if (!mounted) return;

      setState(() {
        _ringkasan = ringkasan;
        _stokMenipis = stokMenipis;
        _transaksi = transaksi;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Gagal memuat data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Selamat datang di KIOS ONE 👋',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            // Tanggal yang sama dengan data yang
            // ditampilkan (bukan waktu build),
            // agar tetap konsisten sebelum
            // pergantian tanggal dimuat ulang.
            'Ringkasan usaha hari ini · '
            '${formatTanggal(_tanggalTerakhir)}',
          ),
          const SizedBox(height: 20),
          if (_loading && _ringkasan == null)
            const Center(child: CircularProgressIndicator())
          else if (_error.isNotEmpty)
            Center(child: Text(_error))
          else ...[
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Penjualan Bersih',
                    value: formatRupiah(_ringkasan!.penjualan),
                    icon: Icons.payments_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Transaksi',
                    value: '${_ringkasan!.jumlahTransaksi}',
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: StatCard(
                title: 'Retur',
                value: formatRupiah(_ringkasan!.totalRetur),
                icon: Icons.assignment_return_outlined,
              ),
            ),
            if (_isAdmin) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Keuntungan',
                      value: formatRupiah(_ringkasan!.keuntungan),
                      icon: Icons.trending_up,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Pengeluaran',
                      value: formatRupiah(_ringkasan!.pengeluaran),
                      icon: Icons.money_off,
                    ),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 20),
          _buildQuickActions(),
          const SizedBox(height: 20),
          _buildStokMenipis(),
          const SizedBox(height: 12),
          _buildTransaksiTerbaru(),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Menu Cepat',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.point_of_sale),
                  label: const Text('Kasir'),
                  onPressed: () =>
                      _buka(context, KasirScreen(idUser: widget.idUser)),
                ),
                ActionChip(
                  avatar: const Icon(Icons.inventory_2),
                  label: const Text('Barang'),
                  onPressed: () =>
                      _buka(context, BarangScreen(readOnly: !_isAdmin)),
                ),
                ActionChip(
                  avatar: const Icon(Icons.assignment_return),
                  label: const Text('Retur Barang'),
                  onPressed: () => _buka(context, ReturScreen()),
                ),
                ActionChip(
                  avatar: const Icon(Icons.receipt_long),
                  label: const Text('Riwayat'),
                  onPressed: () => _buka(context, RiwayatTransaksiScreen()),
                ),
                if (_isAdmin)
                  ActionChip(
                    avatar: const Icon(Icons.add_shopping_cart),
                    label: const Text('Stok Masuk'),
                    onPressed: () => _buka(
                      context,
                      StokMasukScreen(),
                      minimalRole: Role.admin,
                    ),
                  ),
                if (_isAdmin)
                  ActionChip(
                    avatar: const Icon(Icons.category),
                    label: const Text('Kategori'),
                    onPressed: () => _buka(
                      context,
                      KategoriScreen(),
                      minimalRole: Role.admin,
                    ),
                  ),
                if (_isAdmin)
                  ActionChip(
                    avatar: const Icon(Icons.bar_chart),
                    label: const Text('Laporan'),
                    onPressed: () => _buka(
                      context,
                      LaporanScreen(),
                      minimalRole: Role.admin,
                    ),
                  ),
                if (_isAdmin)
                  ActionChip(
                    avatar: const Icon(Icons.download),
                    label: const Text('Pemasukan'),
                    onPressed: () => _buka(
                      context,
                      PemasukanScreen(),
                      minimalRole: Role.admin,
                    ),
                  ),
                if (_isAdmin)
                  ActionChip(
                    avatar: const Icon(Icons.upload),
                    label: const Text('Pengeluaran'),
                    onPressed: () => _buka(
                      context,
                      PengeluaranScreen(),
                      minimalRole: Role.admin,
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.lock_outline),
                  label: const Text('Ganti PIN'),
                  onPressed: () => _buka(
                    context,
                    const GantiPinScreen(),
                    minimalRole: Role.kasir,
                  ),
                ),
                if (_isAdmin)
                  ActionChip(
                    avatar: const Icon(Icons.people_outline),
                    label: const Text('Pengguna'),
                    onPressed: () => _buka(
                      context,
                      const KelolaAkunScreen(),
                      minimalRole: Role.admin,
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.logout_outlined),
                  label: const Text('Keluar'),
                  onPressed: _keluar,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Membuka halaman dengan pemeriksaan
  /// hak akses berdasarkan role.
  Future<void> _buka(
    BuildContext context,
    Widget halaman, {
    Role minimalRole = Role.kasir,
  }) async {
    await bukaHalaman(
      context,
      role: widget.role,
      minimalRole: minimalRole,
      halaman: halaman,
    );

    _loadData();
  }

  /// Keluar dari aplikasi.
  ///
  /// Session dihapus dan kembali
  /// ke halaman pilihan role.
  Future<void> _keluar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Keluar dari KIOS ONE?'),
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

  Widget _buildStokMenipis() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stok Perlu Diperhatikan',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (_loading && _stokMenipis.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_stokMenipis.isEmpty)
              const Text('Semua stok aman.')
            else
              for (final barang in _stokMenipis)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .errorContainer,
                    child: Icon(
                      Icons.warning_amber_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  title: Text(barang.namaBarang),
                  subtitle: Text(
                    'Sisa ${barang.stok} ${barang.satuan} '
                    '(minimum ${barang.stokMinimum})',
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransaksiTerbaru() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transaksi Terbaru',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => _buka(context, RiwayatTransaksiScreen()),
                  child: const Text('Lihat Semua'),
                ),
              ],
            ),
            if (_loading && _transaksi.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_transaksi.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('Belum ada transaksi.')),
              )
            else
              for (final transaksi in _transaksi)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.receipt_outlined),
                  ),
                  title: Text(
                    transaksi.nomorTransaksi,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(formatDateTime(transaksi.tanggal)),
                  trailing: Text(
                    formatRupiah(transaksi.total),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 12),
            Text(title),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
