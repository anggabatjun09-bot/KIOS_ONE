import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/barang.dart';
import '../models/kategori.dart';
import '../services/barang_service.dart';
import '../services/foto_service.dart';
import '../services/kategori_service.dart';
import '../utils/kios_utils.dart';

/// Form tambah/edit barang, termasuk pengelolaan foto:
/// pilih dari galeri, preview, ganti, dan hapus foto.
class FormBarangScreen extends StatefulWidget {
  final Barang? barang;
  final BarangService barangService;
  final FotoService fotoService;
  final KategoriService kategoriService;

  FormBarangScreen({
    super.key,
    this.barang,
    BarangService? barangService,
    FotoService? fotoService,
    KategoriService? kategoriService,
  }) : barangService = barangService ?? BarangService(),
       fotoService = fotoService ?? FotoService(),
       kategoriService = kategoriService ?? KategoriService();

  @override
  State<FormBarangScreen> createState() => _FormBarangScreenState();
}

class _FormBarangScreenState extends State<FormBarangScreen> {
  final _formKey = GlobalKey<FormState>();

  final _kodeController = TextEditingController();
  final _namaController = TextEditingController();
  final _satuanController = TextEditingController();
  final _hargaBeliController = TextEditingController();
  final _hargaJualController = TextEditingController();
  final _stokController = TextEditingController();
  final _stokMinimumController = TextEditingController();

  List<Kategori> _kategori = [];
  int? _idKategoriTerpilih;
  bool _loadingKategori = false;
  String? _errorKategori;
  bool _saving = false;

  /// Path lokal foto baru hasil pilih galeri (belum disimpan permanen).
  String? _fotoBaruPath;

  /// Apakah pengguna menghapus foto lama.
  bool _fotoLamaDihapus = false;

  bool get _editing => widget.barang != null;

  @override
  void initState() {
    super.initState();

    final b = widget.barang;

    _kodeController.text = b?.kodeBarang ?? '';
    _namaController.text = b?.namaBarang ?? '';
    _satuanController.text = b?.satuan ?? '';
    _hargaBeliController.text = _formatAngka(b?.hargaBeli);
    _hargaJualController.text = _formatAngka(b?.hargaJual);
    _stokController.text = (b?.stok ?? 0).toString();
    _stokMinimumController.text = (b?.stokMinimum ?? 5).toString();

    _idKategoriTerpilih = b?.idKategori;

    _loadKategori();
  }

  @override
  void dispose() {
    _kodeController.dispose();
    _namaController.dispose();
    _satuanController.dispose();
    _hargaBeliController.dispose();
    _hargaJualController.dispose();
    _stokController.dispose();
    _stokMinimumController.dispose();
    super.dispose();
  }

  String _formatAngka(double? nilai) {
    if (nilai == null || nilai == 0) return '';
    return nilai.toStringAsFixed(0);
  }

  String? _validasiHarga(String? value) {
    final text = (value ?? '').replaceAll('.', '').trim();
    final harga = text.isEmpty ? 0.0 : double.tryParse(text);

    if (harga == null || !harga.isFinite || harga < 0) {
      return 'Harga harus berupa angka non-negatif';
    }

    return null;
  }

  String? _validasiJumlah(String? value, String label) {
    final jumlah = int.tryParse(value ?? '');

    if (jumlah == null || jumlah < 0) {
      return '$label harus berupa bilangan bulat non-negatif';
    }

    return null;
  }

  Future<void> _loadKategori() async {
    setState(() => _loadingKategori = true);

    try {
      _kategori = await widget.kategoriService.getAll();
      _errorKategori = null;
    } catch (e) {
      _errorKategori = 'Gagal memuat kategori: $e';
    }

    if (mounted) {
      setState(() => _loadingKategori = false);
    }
  }

  // ======================================================
  // FOTO
  // ======================================================

  Future<void> _pilihFoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );

      if (picked == null) return;

      setState(() {
        _fotoBaruPath = picked.path;
        _fotoLamaDihapus = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal memilih foto: $e')));
    }
  }

  void _hapusFoto() {
    setState(() {
      if (_fotoBaruPath != null) {
        _fotoBaruPath = null;
      } else {
        _fotoLamaDihapus = true;
      }
    });
  }

  // ======================================================
  // SIMPAN
  // ======================================================

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final now = DateTime.now().toIso8601String();

      // Tentukan path foto akhir:
      // - foto baru dipilih -> salin ke penyimpanan aplikasi
      // - foto lama dihapus -> hapus file lama
      // - tidak berubah -> pertahankan foto lama
      String? fotoAkhir;

      if (_fotoBaruPath != null) {
        fotoAkhir = await widget.fotoService.simpanDariSumber(_fotoBaruPath!);

        final fotoLama = widget.barang?.foto;
        if (fotoLama != null && fotoLama != fotoAkhir) {
          await widget.fotoService.hapus(fotoLama);
        }
      } else if (_fotoLamaDihapus && widget.barang?.foto != null) {
        await widget.fotoService.hapus(widget.barang!.foto);
        fotoAkhir = null;
      } else {
        fotoAkhir = widget.barang?.foto;
      }

      final barang = Barang(
        idBarang: widget.barang?.idBarang,
        kodeBarang: _kodeController.text.trim(),
        namaBarang: _namaController.text.trim(),
        idKategori: _idKategoriTerpilih,
        satuan: _satuanController.text.trim().isEmpty
            ? 'pcs'
            : _satuanController.text.trim(),
        hargaBeli:
            double.tryParse(_hargaBeliController.text.replaceAll('.', '')) ?? 0,
        hargaJual:
            double.tryParse(_hargaJualController.text.replaceAll('.', '')) ?? 0,
        stok: int.tryParse(_stokController.text) ?? 0,
        stokMinimum: int.tryParse(_stokMinimumController.text) ?? 5,
        foto: fotoAkhir,
        createdAt: widget.barang?.createdAt ?? now,
        updatedAt: now,
      );

      if (_editing) {
        await widget.barangService.update(barang);
      } else {
        await widget.barangService.insert(barang);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editing ? 'Barang diperbarui.' : 'Barang disimpan.'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // ======================================================
  // UI FOTO
  // ======================================================

  Widget _buildFotoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Foto Barang',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildFotoPreview(),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _saving ? null : _pilihFoto,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(_adaFoto ? 'Ganti Foto' : 'Pilih Foto'),
                ),
                if (_adaFoto) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _hapusFoto,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _adaFoto =>
      _fotoBaruPath != null ||
      (!_fotoLamaDihapus && widget.barang?.foto != null);

  Widget _buildFotoPreview() {
    // Foto baru dari galeri.
    if (_fotoBaruPath != null) {
      return _buildPreviewFile(File(_fotoBaruPath!));
    }

    // Foto lama yang tersimpan di penyimpanan aplikasi.
    if (!_fotoLamaDihapus && widget.barang?.foto != null) {
      return FutureBuilder<File?>(
        future: widget.fotoService.file(widget.barang!.foto),
        builder: (context, snapshot) {
          final file = snapshot.data;

          if (snapshot.connectionState == ConnectionState.done &&
              file != null) {
            return _buildPreviewFile(file);
          }

          return _buildPlaceholder(
            ikon: Icons.broken_image_outlined,
            teks: 'Foto tidak ditemukan',
          );
        },
      );
    }

    return _buildPlaceholder(
      ikon: Icons.add_photo_alternate_outlined,
      teks: 'Belum ada foto',
    );
  }

  Widget _buildPreviewFile(File file) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        file,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildPlaceholder({required IconData ikon, required String teks}) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            ikon,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(teks),
        ],
      ),
    );
  }

  // ======================================================
  // FORM
  // ======================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit Barang' : 'Tambah Barang')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildFotoSection(),
            const SizedBox(height: 16),
            TextFormField(
              controller: _kodeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Kode Barang',
                prefixIcon: Icon(Icons.qr_code),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Kode barang wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _namaController,
              decoration: const InputDecoration(
                labelText: 'Nama Barang',
                prefixIcon: Icon(Icons.inventory_2_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama barang wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildKategoriDropdown(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _hargaBeliController,
                    keyboardType: TextInputType.number,
                    validator: _validasiHarga,
                    decoration: InputDecoration(
                      labelText: 'Harga Beli',
                      prefixIcon: const Icon(Icons.shopping_bag_outlined),
                      border: const OutlineInputBorder(),
                      hintText: formatRupiah(0),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _hargaJualController,
                    keyboardType: TextInputType.number,
                    validator: _validasiHarga,
                    decoration: InputDecoration(
                      labelText: 'Harga Jual',
                      prefixIcon: const Icon(Icons.payments_outlined),
                      border: const OutlineInputBorder(),
                      hintText: formatRupiah(0),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stokController,
                    keyboardType: TextInputType.number,
                    validator: (value) => _validasiJumlah(value, 'Stok'),
                    decoration: const InputDecoration(
                      labelText: 'Stok',
                      prefixIcon: Icon(Icons.inventory_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stokMinimumController,
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        _validasiJumlah(value, 'Stok minimum'),
                    decoration: const InputDecoration(
                      labelText: 'Stok Minimum',
                      prefixIcon: Icon(Icons.warning_amber_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _satuanController,
              decoration: const InputDecoration(
                labelText: 'Satuan',
                prefixIcon: Icon(Icons.straighten),
                border: OutlineInputBorder(),
                hintText: 'pcs',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _simpan,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_editing ? 'SIMPAN PERUBAHAN' : 'SIMPAN'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildKategoriDropdown() {
    if (_errorKategori != null) {
      return Text(_errorKategori!);
    }

    return DropdownButtonFormField<int>(
      initialValue: _idKategoriTerpilih,
      decoration: const InputDecoration(
        labelText: 'Kategori',
        prefixIcon: Icon(Icons.category_outlined),
        border: OutlineInputBorder(),
      ),
      items: [
        if (_idKategoriTerpilih != null &&
            !_kategori.any((k) => k.idKategori == _idKategoriTerpilih))
          DropdownMenuItem(
            value: _idKategoriTerpilih,
            child: const Text('(Kategori tidak ditemukan)'),
          ),
        ..._kategori.map(
          (k) => DropdownMenuItem(
            value: k.idKategori,
            child: Text(k.namaKategori),
          ),
        ),
      ],
      onChanged: _loadingKategori
          ? null
          : (value) {
              setState(() => _idKategoriTerpilih = value);
            },
    );
  }
}
