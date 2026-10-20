import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/struk.dart';
import '../services/struk_service.dart';

/// Pratinjau struk PDF untuk satu transaksi.
///
/// Pratinjau dan bagikan berjalan secara
/// offline tanpa memerlukan printer fisik.
/// Halaman ini hanya membaca data
/// transaksi yang sudah tersimpan.
class StrukPreviewScreen extends StatefulWidget {
  final int idPenjualan;
  final StrukService strukService;

  StrukPreviewScreen({
    super.key,
    required this.idPenjualan,
    StrukService? strukService,
  }) : strukService = strukService ?? StrukService();

  @override
  State<StrukPreviewScreen> createState() => _StrukPreviewScreenState();
}

class _StrukPreviewScreenState extends State<StrukPreviewScreen> {
  StrukData? _struk;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadStruk();
  }

  Future<void> _loadStruk() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final data = await widget.strukService.siapkanStruk(
        widget.idPenjualan,
      );

      if (!mounted) return;

      setState(() {
        _struk = data;
        _loading = false;

        if (data == null) {
          _error = 'Transaksi tidak ditemukan.';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Gagal membuat struk: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final struk = _struk;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Struk PDF'),
      ),
      body: struk == null
          ? Center(
              child: _loading
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error,
                        textAlign: TextAlign.center,
                      ),
                    ),
            )
          // PdfPreview menampilkan struk
          // beserta aksi cetak/bagikan.
          // Pratinjau berjalan tanpa printer.
          : PdfPreview(
              pdfFileName: struk.namaFile,
              useActions: true,
              canChangeOrientation: false,
              maxPageWidth: 400,
              build: (format) =>
                  widget.strukService.strukPdf(struk),
            ),
    );
  }
}
