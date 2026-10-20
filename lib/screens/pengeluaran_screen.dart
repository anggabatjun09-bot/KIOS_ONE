import 'package:flutter/material.dart';

import '../models/pengeluaran.dart';
import '../services/pengeluaran_service.dart';
import '../utils/kios_utils.dart';

/// Form dan daftar pengeluaran.
class PengeluaranScreen extends StatefulWidget {
  final PengeluaranService pengeluaranService;

  PengeluaranScreen({super.key, PengeluaranService? pengeluaranService})
    : pengeluaranService = pengeluaranService ?? PengeluaranService();

  @override
  State<PengeluaranScreen> createState() => _PengeluaranScreenState();
}

class _PengeluaranScreenState extends State<PengeluaranScreen> {
  final _formKey = GlobalKey<FormState>();

  final _kategoriController = TextEditingController();
  final _nominalController = TextEditingController();
  final _keteranganController = TextEditingController();

  static const _kategoriUmum = [
    'Gaji',
    'Listrik',
    'Air',
    'Sewa',
    'Transport',
    'Internet',
    'Lainnya',
  ];

  bool _saving = false;
  List<Pengeluaran> _daftar = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _kategoriController.dispose();
    _nominalController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      _daftar = await widget.pengeluaranService.getAll();
    } catch (e) {
      _loadError = 'Gagal memuat pengeluaran: $e';
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    final nominal =
        double.tryParse(_nominalController.text.replaceAll('.', '')) ?? 0;

    setState(() => _saving = true);

    try {
      await widget.pengeluaranService.insert(
        Pengeluaran(
          tanggal: DateTime.now().toIso8601String(),
          kategori: _kategoriController.text.trim(),
          nominal: nominal,
          keterangan: _keteranganController.text.trim().isEmpty
              ? null
              : _keteranganController.text.trim(),
        ),
      );

      _kategoriController.clear();
      _nominalController.clear();
      _keteranganController.clear();

      await _loadData();

      _snackbar('Pengeluaran disimpan.');
    } catch (e) {
      _snackbar('Gagal menyimpan: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _snackbar(String pesan) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Catat Pengeluaran',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _kategoriController,
                        decoration: InputDecoration(
                          labelText: 'Kategori',
                          prefixIcon: const Icon(Icons.category_outlined),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Kategori wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final kategori in _kategoriUmum)
                            ActionChip(
                              label: Text(kategori),
                              onPressed: () {
                                setState(() {
                                  _kategoriController.text = kategori;
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nominalController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Nominal',
                          prefixIcon: const Icon(Icons.money_outlined),
                          border: const OutlineInputBorder(),
                          hintText: formatRupiah(0),
                        ),
                        validator: (value) {
                          final nominal = double.tryParse(value ?? '') ?? 0;
                          if (nominal <= 0) {
                            return 'Nominal harus > 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _keteranganController,
                        decoration: const InputDecoration(
                          labelText: 'Keterangan (opsional)',
                          prefixIcon: Icon(Icons.note_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _simpan,
                          icon: _saving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(_saving ? 'MENYIMPAN...' : 'SIMPAN'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Daftar Pengeluaran',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_loadError != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_loadError!),
                ),
              )
            else if (_daftar.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Belum ada pengeluaran.')),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (final p in _daftar)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.arrow_upward),
                        title: Text(p.kategori),
                        subtitle: Text(formatDateTime(p.tanggal)),
                        trailing: Text(
                          formatRupiah(p.nominal),
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
