import 'package:flutter/material.dart';

import '../models/user.dart';

/// Membuka halaman hanya jika role pengguna
/// memenuhi level yang dipersyaratkan.
///
/// Jika tidak diizinkan, navigasi DITOLAK
/// dan pesan ditampilkan — bukan sekadar
/// menyembunyikan tombol.
Future<void> bukaHalaman(
  BuildContext context, {
  required Role role,
  required Role minimalRole,
  required Widget halaman,
  String? pesan,
}) async {
  if (role.index < minimalRole.index) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pesan ??
                'Akses ditolak. '
                'Hanya admin yang dapat membuka halaman ini.',
          ),
        ),
      );
    }

    return;
  }

  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => halaman),
  );
}
