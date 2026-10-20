import 'package:flutter/material.dart';

import '../models/barang.dart';
import '../models/stok_masuk.dart';
import '../services/barang_service.dart';
import '../services/stok_masuk_service.dart';
import '../utils/kios_utils.dart';

/// Form dan riwayat stok masuk.
class StokMasukScreen extends StatefulWidget {
  final StokMasukService stokMasukService;
  final BarangService barangService;

  StokMasukScreen({
    super.key,
    StokMasukService? stokMasukService,
    BarangService? barangService,
  }) : stokMasukService = stokMasukService ?? StokMasukService(),
       barangService = barangService ?? BarangService();

  @override
  State<StokMasukScreen> createState() => _StokMasukScreenState();
}

class _StokMasukScreenState extends State<StokMasukScreen> {
  final _formKey = GlobalKey<FormState>();

  final _jumlahController = TextEditingController();
  final _hargaController = TextEditingController();
  final _keteranganController = TextEditingController();

  List<Barang> _barang = [];
  int? _idBarangTerpilih;
  bool _loadingKategori = false;
  String? _errorBarang;
  bool _saving = false;

  List<StokMasuk> _riwayat = [];
  bool _loadingRiwayat = true;
  String? _errorRiwayat;

  @override
  void initState() {
    super.initState();
    _loadBarang();
    _loadRiwayat();
  }

  @override
  void dispose() {
    _jumlahController.dispose();
    _hargaController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _loadBarang() async {
    setState(() => _loadingKategori = true);

    try {
      _barang = await widget.barangService.getAll();
      _errorBarang = null;

      if (_idBarangTerpilih == null && _barang.isNotEmpty) {
        _idBarangTerpilih = _barang.first.idBarang;
        _hargaController.text = _barang.first.hargaBeli.toStringAsFixed(0);
      }
    } catch (e) {
      _errorBarang = 'Gagal memuat barang: $e';
    }

    if (mounted) {
      setState(() => _loadingKategori = false);
    }
  }

  Future<void> _loadRiwayat() async {
    setState(() {
      _loadingRiwayat = true;
      _errorRiwayat = null;
    });

    try {
      _riwayat = await widget.stokMasukService.getRiwayat();
    } catch (e) {
      _errorRiwayat = 'Gagal memuat riwayat stok masuk: $e';
    }

    if (mounted) {
      setState(() => _loadingRiwayat = false);
    }
  }

  void _onBarangDipilih(int? id) {
    setState(() => _idBarangTerpilih = id);

    final barang = _barang.cast<Barang?>().firstWhere(
      (b) => b!.idBarang == id,
      orElse: () => null,
    );

    if (barang != null) {
      _hargaController.text = barang.hargaBeli.toStringAsFixed(0);
    }
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    final idBarang = _idBarangTerpilih;

    if (idBarang == null) {
      _snackbar('Pilih barang terlebih dahulu.');
      return;
    }

    final jumlah = int.tryParse(_jumlahController.text) ?? 0;
    final harga =
        double.tryParse(_hargaController.text.replaceAll('.', '')) ?? 0;

    setState(() => _saving = true);

    try {
      await widget.stokMasukService.tambah(
        idBarang: idBarang,
        jumlah: jumlah,
        hargaBeli: harga,
        keterangan: _keteranganController.text.trim().isEmpty
            ? null
            : _keteranganController.text.trim(),
      );

      _jumlahController.clear();
      _keteranganController.clear();

      await _loadRiwayat();

      _snackbar('Stok masuk dicatat.');
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
        onRefresh: _loadRiwayat,
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
                        'Catat Stok Masuk',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDropdownBarang(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _jumlahController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Jumlah',
                                prefixIcon: Icon(Icons.add_shopping_cart),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final jumlah = int.tryParse(value ?? '');
                                if (jumlah == null || jumlah <= 0) {
                                  return 'Jumlah harus > 0';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _hargaController,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final text = (value ?? '')
                                    .replaceAll('.', '')
                                    .trim();
                                final harga = text.isEmpty
                                    ? 0.0
                                    : double.tryParse(text);

                                if (harga == null ||
                                    !harga.isFinite ||
                                    harga < 0) {
                                  return 'Harga harus >= 0';
                                }

                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: 'Harga Beli',
                                prefixIcon: const Icon(Icons.money),
                                border: const OutlineInputBorder(),
                                hintText: formatRupiah(0),
                              ),
                            ),
                          ),
                        ],
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
                          label: Text(
                            _saving ? 'MENYIMPAN...' : 'SIMPAN STOK MASUK',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Riwayat Stok Masuk',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_loadingRiwayat)
              const Center(child: CircularProgressIndicator())
            else if (_errorRiwayat != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_errorRiwayat!),
                ),
              )
            else if (_riwayat.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Belum ada stok masuk.')),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (final record in _riwayat)
                      ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.add_shopping_cart),
                        ),
                        title: Text(
                          record.namaBarang ?? 'Barang #${record.idBarang}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${formatDateTime(record.tanggal)}'
                          ' · ${formatRupiah(record.hargaBeli)}'
                          '/pcs',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '+${record.jumlah}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(formatRupiah(record.subtotal)),
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

  Widget _buildDropdownBarang() {
    if (_errorBarang != null) {
      return Text(_errorBarang!);
    }

    if (_barang.isEmpty && !_loadingKategori) {
      return const Text('Belum ada barang. Tambahkan barang terlebih dahulu.');
    }

    return DropdownButtonFormField<int>(
      initialValue: _idBarangTerpilih,
      decoration: const InputDecoration(
        labelText: 'Pilih Barang',
        prefixIcon: Icon(Icons.inventory_2_outlined),
        border: OutlineInputBorder(),
      ),
      items: [
        if (_idBarangTerpilih != null &&
            !_barang.any((b) => b.idBarang == _idBarangTerpilih))
          DropdownMenuItem(
            value: _idBarangTerpilih,
            child: const Text('(Barang tidak ditemukan)'),
          ),
        ..._barang.map(
          (b) => DropdownMenuItem(
            value: b.idBarang,
            child: Text(
              '${b.namaBarang} '
              '(stok ${b.stok})',
            ),
          ),
        ),
      ],
      onChanged: _loadingKategori ? null : _onBarangDipilih,
    );
  }
}
