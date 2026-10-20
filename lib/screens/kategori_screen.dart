import 'package:flutter/material.dart';

import '../models/kategori.dart';
import '../services/kategori_service.dart';

/// Kelola kategori barang: tambah, edit, hapus.
class KategoriScreen extends StatefulWidget {
  final KategoriService kategoriService;

  KategoriScreen({super.key, KategoriService? kategoriService})
    : kategoriService = kategoriService ?? KategoriService();

  @override
  State<KategoriScreen> createState() => _KategoriScreenState();
}

class _KategoriScreenState extends State<KategoriScreen> {
  final _searchController = TextEditingController();
  final _namaController = TextEditingController();

  List<Kategori> _kategori = [];
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
    _namaController.dispose();
    super.dispose();
  }

  void _onSearchChanged() => _loadData();

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      var daftar = await widget.kategoriService.getAll();

      final keyword = _searchController.text.trim().toLowerCase();

      if (keyword.isNotEmpty) {
        daftar = daftar
            .where((k) => k.namaKategori.toLowerCase().contains(keyword))
            .toList();
      }

      if (!mounted) return;

      setState(() {
        _kategori = daftar;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Gagal memuat kategori: $e';
      });
    }
  }

  Future<void> _tambahKategori() async {
    final nama = _namaController.text.trim();

    if (nama.isEmpty) {
      _snackbar('Nama kategori tidak boleh kosong');
      return;
    }

    try {
      await widget.kategoriService.insert(Kategori(namaKategori: nama));

      _namaController.clear();

      await _loadData();

      _snackbar('Kategori "$nama" ditambahkan.');
    } catch (e) {
      _snackbar('Gagal menambahkan: ${_pesanKesalahan(e)}');
    }
  }

  Future<void> _editKategori(Kategori kategori) async {
    final controller = TextEditingController(text: kategori.namaKategori);

    final nama = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Kategori'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nama Kategori',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('SIMPAN'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (nama == null || nama.isEmpty) return;

    try {
      await widget.kategoriService.update(
        Kategori(idKategori: kategori.idKategori, namaKategori: nama),
      );

      await _loadData();

      _snackbar('Kategori diperbarui.');
    } catch (e) {
      _snackbar('Gagal memperbarui: ${_pesanKesalahan(e)}');
    }
  }

  Future<void> _hapusKategori(Kategori kategori) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text('Hapus kategori "${kategori.namaKategori}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.kategoriService.delete(kategori.idKategori!);

      await _loadData();

      _snackbar('Kategori dihapus.');
    } catch (e) {
      _snackbar('Gagal menghapus: ${_pesanKesalahan(e)}');
    }
  }

  void _snackbar(String pesan) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  String _pesanKesalahan(Object e) {
    final teks = e.toString();

    if (teks.contains('UNIQUE')) {
      return 'Kategori sudah ada.';
    }

    if (teks.contains('FOREIGN KEY')) {
      return 'Kategori masih dipakai barang.';
    }

    return teks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading && _kategori.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SearchBar(
                    controller: _searchController,
                    hintText: 'Cari kategori...',
                    leading: const Icon(Icons.search),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _namaController,
                              decoration: const InputDecoration(
                                labelText: 'Nama Kategori Baru',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _tambahKategori(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _tambahKategori,
                            icon: const Icon(Icons.add),
                            label: const Text('Tambah'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error.isNotEmpty)
                    Center(child: Text(_error))
                  else if (_kategori.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('Belum ada kategori.')),
                      ),
                    )
                  else
                    Card(
                      child: Column(
                        children: [
                          for (final kategori in _kategori)
                            ListTile(
                              leading: const Icon(Icons.category_outlined),
                              title: Text(
                                kategori.namaKategori,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _editKategori(kategori),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _hapusKategori(kategori),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
