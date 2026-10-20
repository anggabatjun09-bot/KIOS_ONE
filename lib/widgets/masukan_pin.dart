import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Indikator PIN berupa titik.
///
/// PIN tidak pernah ditampilkan
/// sebagai teks biasa.
class IndikatorPin extends StatelessWidget {
  final int jumlah;
  final int panjang;

  const IndikatorPin({super.key, required this.jumlah, this.panjang = 6});

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        panjang,
        (i) {
          final terisi = i < jumlah;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 7),
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: terisi ? skema.primary : skema.outlineVariant,
            ),
          );
        },
      ),
    );
  }
}

/// Keypad angka 0 sampai 9 dengan
/// tombol hapus satu digit dan
/// tombol hapus semua.
///
/// Ukuran tombol mengikuti area
/// yang tersedia sehingga seluruh
/// angka selalu terlihat dan dapat
/// diketik pada layar apa pun.
class KeypadPin extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onHapusSatu;
  final VoidCallback onHapusSemua;

  const KeypadPin({
    super.key,
    required this.onDigit,
    required this.onHapusSatu,
    required this.onHapusSemua,
  });

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = math.min(
          constraints.maxWidth / 3,
          constraints.maxHeight / 4,
        );

        Widget sel(Widget isi) {
          return Expanded(
            child: Center(
              child: SizedBox(
                width: diameter,
                height: diameter,
                child: isi,
              ),
            ),
          );
        }

        Widget tombolAngka(String digit) {
          return sel(
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                backgroundColor: skema.surfaceContainerHighest,
                foregroundColor: skema.onSurface,
                elevation: 0,
              ),
              onPressed: () => onDigit(digit),
              child: Text(
                digit,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }

        Widget tombolIkon({
          required IconData ikon,
          required String tooltip,
          required VoidCallback onTap,
        }) {
          return sel(
            IconButton(
              iconSize: 30,
              tooltip: tooltip,
              onPressed: onTap,
              icon: Icon(ikon, color: skema.onSurfaceVariant),
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  tombolAngka('1'),
                  tombolAngka('2'),
                  tombolAngka('3'),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  tombolAngka('4'),
                  tombolAngka('5'),
                  tombolAngka('6'),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  tombolAngka('7'),
                  tombolAngka('8'),
                  tombolAngka('9'),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  tombolIkon(
                    ikon: Icons.delete_sweep_outlined,
                    tooltip: 'Hapus semua',
                    onTap: onHapusSemua,
                  ),
                  tombolAngka('0'),
                  tombolIkon(
                    ikon: Icons.backspace_outlined,
                    tooltip: 'Hapus satu digit',
                    onTap: onHapusSatu,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
