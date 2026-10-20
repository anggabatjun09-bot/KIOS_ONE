import 'package:flutter/material.dart';

import 'ganti_pin_screen.dart';

/// Profil Admin.
///
/// Halaman ini sengaja dibuat sederhana:
/// hanya identitas kios dan tombol
/// Ganti PIN. Pengaturan lain tidak
/// ditampilkan di sini.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.store),
            ),
            title: const Text(
              'KIOS ONE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'Aplikasi kasir dan persediaan',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Ganti PIN'),
            subtitle: const Text('Ubah PIN'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const GantiPinScreen(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
