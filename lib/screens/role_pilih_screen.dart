import 'package:flutter/material.dart';

import '../models/user.dart';
import 'login_screen.dart';

/// Halaman awal: pilih peran sebelum login.
///
/// Pilihan role hanya menentukan jenis
/// akun yang diharapkan. Hak akses
/// ditentukan oleh verifikasi database,
/// bukan oleh tombol yang ditekan.
class RolePilihScreen extends StatelessWidget {
  const RolePilihScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 40),
            Icon(
              Icons.storefront,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'KIOS ONE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kasir & Manajemen Persediaan',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Masuk sebagai',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            _buildPilihan(
              context,
              role: Role.admin,
              ikon: Icons.admin_panel_settings_outlined,
              judul: 'Admin',
              deskripsi:
                  'Kelola barang, kategori, stok, '
                  'laporan, dan pengguna',
            ),
            const SizedBox(height: 16),
            _buildPilihan(
              context,
              role: Role.kasir,
              ikon: Icons.point_of_sale_outlined,
              judul: 'Kasir',
              deskripsi:
                  'Jual barang, kelola keranjang, '
                  'dan proses pembayaran',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPilihan(
    BuildContext context, {
    required Role role,
    required IconData ikon,
    required String judul,
    required String deskripsi,
  }) {
    final skema = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LoginScreen(role: role),
          ),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: skema.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: skema.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: skema.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(ikon, color: skema.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Masuk sebagai $judul',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      deskripsi,
                      style: TextStyle(
                        color: skema.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
