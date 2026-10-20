import 'dart:io';

import 'package:flutter/material.dart';

import '../models/barang.dart';
import '../services/barang_service.dart';
import '../services/foto_service.dart';
import '../utils/kios_utils.dart';
import 'form_barang_screen.dart';

/// Daftar barang dengan thumbnail foto.
///
/// Jika [readOnly] true (role kasir),
/// tombol tambah/edit/hapus disembunyikan
/// dan operasi penulisan ditolak.
class BarangScreen extends StatefulWidget {
  final BarangService barangService;
  final FotoService fotoService;
  final bool readOnly;

  BarangScreen({
    super.key,
    BarangService? barangService,
    FotoService? fotoService,
    this.readOnly = false,
  }) : barangService = barangService ?? BarangService(),
       fotoService = fotoService ?? FotoService();

  @override
  State<BarangScreen> createState() => _BarangScreenState();
}

class _BarangScreenState extends State<BarangScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<Barang> _barang = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() => _loadData();

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final hasil = await widget.barangService.getAll(
        keyword: _searchController.text,
      );

      if (!mounted) return;

      setState(() {
        _barang = hasil;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Gagal memuat data barang: $e';
      });
    }
  }

  Future<void> _hapus(Barang barang) async {
    if (widget.readOnly) {
      _snackbar('Hanya admin yang dapat menghapus barang.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Barang'),
        content: Text(
          'Hapus "${barang.namaBarang}"? Data transaksi barang ini tidak diubah.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.barangService.delete(barang.idBarang!);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${barang.namaBarang} dihapus.')));

      _loadData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
    }
  }

  Future<void> _bukaForm({Barang? barang}) async {
    if (widget.readOnly) {
      _snackbar('Hanya admin yang dapat menambah atau mengedit barang.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormBarangScreen(
          barang: barang,
          barangService: widget.barangService,
          fotoService: widget.fotoService,
        ),
      ),
    );

    _loadData();
  }

  void _snackbar(String pesan) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(pesan)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading && _barang.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error, textAlign: TextAlign.center),
                ),
              )
            : _barang.isEmpty
            ? _buildEmpty()
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _barang.length,
                itemBuilder: (context, index) {
                  final item = _barang[index];
                  return _buildItem(item);
                },
              ),
      ),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _bukaForm(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Barang'),
            ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 60),
                const SizedBox(height: 12),
                const Text(
                  'Belum ada barang',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tambahkan barang pertama Anda.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                if (!widget.readOnly)
                  FilledButton.icon(
                    onPressed: () => _bukaForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Barang'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItem(Barang item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: ThumbnailFoto(
          pathRelatif: item.foto,
          fotoService: widget.fotoService,
        ),
        title: Text(
          item.namaBarang,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${item.kodeBarang} · Stok ${item.stok} ${item.satuan}'),
            const SizedBox(height: 2),
            Text(
              formatRupiah(item.hargaJual.toInt()),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        trailing: widget.readOnly
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                    onPressed: () => _bukaForm(barang: item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Hapus',
                    onPressed: () => _hapus(item),
                  ),
                ],
              ),
        onTap: () => _bukaForm(barang: item),
      ),
    );
  }
}

/// Thumbnail foto barang. Menampilkan foto dari penyimpanan
/// aplikasi, atau ikon placeholder jika tanpa foto.
///
/// Future pemuatan foto disimpan di State agar tidak
/// dibuat ulang setiap build (mencegah loop rebuild).
class ThumbnailFoto extends StatefulWidget {
  final String? pathRelatif;
  final FotoService fotoService;

  const ThumbnailFoto({
    super.key,
    required this.pathRelatif,
    required this.fotoService,
  });

  @override
  State<ThumbnailFoto> createState() => _ThumbnailFotoState();
}

class _ThumbnailFotoState extends State<ThumbnailFoto> {
  Future<File?>? _fileFoto;

  @override
  void initState() {
    super.initState();
    _muatFoto();
  }

  @override
  void didUpdateWidget(ThumbnailFoto oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.pathRelatif != widget.pathRelatif) {
      _muatFoto();
    }
  }

  void _muatFoto() {
    final path = widget.pathRelatif;

    if (path == null || path.isEmpty) {
      _fileFoto = null;
    } else {
      _fileFoto = widget.fotoService.file(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fileFoto == null) {
      return _buildPlaceholder(Icons.image_outlined);
    }

    return FutureBuilder<File?>(
      future: _fileFoto,
      builder: (context, snapshot) {
        final file = snapshot.data;

        if (snapshot.connectionState == ConnectionState.done &&
            file != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(file, width: 56, height: 56, fit: BoxFit.cover),
          );
        }

        return _buildPlaceholder(Icons.broken_image_outlined);
      },
    );
  }

  Widget _buildPlaceholder(IconData ikon) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        ikon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
