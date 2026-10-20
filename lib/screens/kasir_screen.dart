import 'package:flutter/material.dart';

import '../models/barang.dart';
import '../services/auth_session.dart';
import '../services/barang_service.dart';
import '../services/foto_service.dart';
import '../services/penjualan_service.dart';
import '../screens/riwayat_transaksi_screen.dart';
import '../screens/struk_preview_screen.dart';
import '../utils/kios_utils.dart';
import 'barang_screen.dart' show ThumbnailFoto;

/// Layar kasir: pilih barang, keranjang, pembayaran,
/// dan penyimpanan transaksi.
///
/// Struktur UI:
/// - Header tetap (judul + pencarian)
/// - Daftar produk (scrollable)
/// - Panel keranjang (flexible, responsif)
/// - Ringkasan pembayaran (selalu terlihat,
///   tetap di atas keyboard)
///
/// Saat keyboard muncul, badan menyusut dan
/// batas tinggi panel keranjang mengikuti
/// ruang yang tersedia agar layout tidak
/// meluber.
class KasirScreen extends StatefulWidget {
  final BarangService barangService;
  final PenjualanService penjualanService;
  final FotoService fotoService;
  final int? idUser;

  KasirScreen({
    super.key,
    BarangService? barangService,
    PenjualanService? penjualanService,
    FotoService? fotoService,
    this.idUser,
  }) : barangService = barangService ?? BarangService(),
       penjualanService = penjualanService ?? PenjualanService(),
       fotoService = fotoService ?? FotoService();

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen> {
  final _searchController = TextEditingController();
  final _bayarController = TextEditingController();

  List<Barang> _barang = [];
  bool _loading = true;
  String? _errorBarang;

  /// Keranjang: id_barang -> jumlah.
  final Map<int, int> _keranjang = {};

  bool _proses = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_loadBarang);

    // Perbarui kembalian secara langsung
    // saat nominal pembayaran diketik.
    _bayarController.addListener(_perbaruiKembalian);

    _loadBarang();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bayarController.dispose();
    super.dispose();
  }

  void _perbaruiKembalian() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadBarang() async {
    try {
      final hasil = await widget.barangService.getAll(
        keyword: _searchController.text,
      );

      if (!mounted) return;

      setState(() {
        _barang = hasil;
        _loading = false;
        _errorBarang = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorBarang = 'Gagal memuat barang: $e';
      });
    }
  }

  Barang? _barangById(int id) {
    for (final b in _barang) {
      if (b.idBarang == id) return b;
    }
    return null;
  }

  double get _total {
    var total = 0.0;

    _keranjang.forEach((id, qty) {
      final b = _barangById(id);

      if (b != null) {
        total += b.hargaJual * qty;
      }
    });

    return total;
  }

  int get _jumlahItem {
    var jumlah = 0;

    _keranjang.forEach((_, qty) => jumlah += qty);

    return jumlah;
  }

  double get _kembalian {
    final bayar =
        double.tryParse(_bayarController.text.replaceAll('.', '')) ?? 0;

    return bayar >= _total ? bayar - _total : 0;
  }

  void _tambahKeKeranjang(Barang barang) {
    if (barang.stok <= 0) {
      _snackbar('Stok ${barang.namaBarang} habis.');
      return;
    }

    setState(() {
      final saatIni = _keranjang[barang.idBarang!] ?? 0;

      if (saatIni >= barang.stok) {
        _snackbar('Melebihi stok tersedia (${barang.stok}).');
        return;
      }

      _keranjang[barang.idBarang!] = saatIni + 1;
    });
  }

  void _ubahQty(int idBarang, int delta) {
    setState(() {
      final saatIni = _keranjang[idBarang] ?? 0;
      final baru = saatIni + delta;

      if (baru <= 0) {
        _keranjang.remove(idBarang);
      } else {
        final barang = _barangById(idBarang);

        if (barang != null && baru > barang.stok) {
          _snackbar('Melebihi stok tersedia (${barang.stok}).');
          return;
        }

        _keranjang[idBarang] = baru;
      }
    });
  }

  void _hapusDariKeranjang(int idBarang) {
    setState(() => _keranjang.remove(idBarang));
  }

  Future<void> _prosesTransaksi() async {
    if (_keranjang.isEmpty) {
      _snackbar('Keranjang masih kosong.');
      return;
    }

    var idUser = widget.idUser;

    if (idUser == null) {
      final userSaatIni = await AuthSession().currentUser();
      idUser = userSaatIni?.idUser;
    }

    if (idUser == null) {
      _snackbar('Sesi pengguna tidak tersedia. Silakan login ulang.');
      return;
    }

    final bayar =
        double.tryParse(_bayarController.text.replaceAll('.', '')) ?? 0;

    if (bayar < _total) {
      _snackbar('Pembayaran kurang. Kembalian tidak bisa negatif.');
      return;
    }

    setState(() => _proses = true);

    try {
      final items = _keranjang.entries.map((entry) {
        final barang = _barangById(entry.key)!;

        return ItemJual(
          idBarang: barang.idBarang!,
          jumlah: entry.value,
          hargaJual: barang.hargaJual,
          hargaBeli: barang.hargaBeli,
        );
      }).toList();

      final penjualan = await widget.penjualanService.buatTransaksi(
        items: items,
        bayar: bayar,
        idUser: idUser,
      );

      _keranjang.clear();
      _bayarController.clear();

      await _loadBarang();

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Transaksi Berhasil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nomor: ${penjualan.nomorTransaksi}'),
              const SizedBox(height: 8),
              Text('Total: ${formatRupiah(penjualan.total)}'),
              Text('Bayar: ${formatRupiah(penjualan.bayar)}'),
              Text(
                'Kembalian: ${formatRupiah(penjualan.kembalian)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('TUTUP'),
            ),
            FilledButton.icon(
              onPressed: () {
                // Tutup dialog, lalu buka struk
                // PDF dari transaksi yang baru
                // disimpan. Tidak ada transaksi
                // baru maupun perubahan stok.
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StrukPreviewScreen(idPenjualan: penjualan.idPenjualan!),
                  ),
                );
              },
              icon: const Icon(Icons.receipt_long),
              label: const Text('LIHAT STRUK PDF'),
            ),
          ],
        ),
      );
    } catch (e) {
      _snackbar('Gagal menyimpan transaksi: $e');
    } finally {
      if (mounted) {
        setState(() => _proses = false);
      }
    }
  }

  void _snackbar(String pesan) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  @override
  Widget build(BuildContext context) {
    // Ruang yang ditempati keyboard, jika ada.
    final keyboardTerbuka = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      // Badan menyusut saat keyboard Android muncul
      // agar pencarian, daftar produk, dan keranjang
      // tidak tertutup keyboard.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        // LayoutBuilder mengambil tinggi badan yang
        // benar-benar tersedia (sudah dikurangi
        // keyboard), sehingga batas tinggi panel
        // keranjang tidak memakai tinggi layar penuh
        // dan layout tidak meluber saat keyboard
        // terbuka.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final panelKeranjang = _buildPanelKeranjang(constraints.maxHeight);

            return Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildDaftarProduk()),
                // Saat keyboard terbuka, panel
                // keranjang menjadi Flexible.loose
                // agar menyusut mengikuti ruang yang
                // tersisa dan layout tidak meluber
                // pada tinggi keyboard apa pun.
                if (keyboardTerbuka)
                  Flexible(child: panelKeranjang)
                else
                  panelKeranjang,
                _buildRingkasanPembayaran(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Kasir',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SearchBar(
            controller: _searchController,
            hintText: 'Cari barang...',
            leading: const Icon(Icons.search),
          ),
        ],
      ),
    );
  }

  Widget _buildDaftarProduk() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorBarang != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_errorBarang!, textAlign: TextAlign.center),
        ),
      );
    }

    if (_barang.isEmpty) {
      return const Center(child: Text('Barang tidak ditemukan.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _barang.length,
      itemBuilder: (context, index) {
        return _buildItemBarang(_barang[index]);
      },
    );
  }

  Widget _buildItemBarang(Barang item) {
    final qty = _keranjang[item.idBarang!] ?? 0;

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
        subtitle: Text(
          '${item.kodeBarang} · Stok ${item.stok} ${item.satuan}'
          '${qty > 0 ? ' · di keranjang $qty' : ''}',
        ),
        trailing: FilledButton.icon(
          onPressed: () => _tambahKeKeranjang(item),
          icon: const Icon(Icons.add_shopping_cart, size: 16),
          label: const Text('Tambah'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ),
    );
  }

  /// Panel keranjang. Hanya tampil bila ada item.
  /// Tingginya dibatasi dan dapat menyusut
  /// agar daftar produk dan ringkasan tetap terlihat.
  ///
  /// [tinggiTersedia] adalah tinggi badan setelah
  /// keyboard mengurangi ruang layar. Batas tinggi
  /// dihitung dari nilai ini agar panel menyusut
  /// bersama layout saat keyboard terbuka.
  Widget _buildPanelKeranjang(double tinggiTersedia) {
    if (_keranjang.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: BoxConstraints(maxHeight: tinggiTersedia * 0.30),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Lebar teks dibuat fleksibel agar
                // header tetap muat di layar sempit
                // dan tidak meluber ke kanan.
                Flexible(
                  child: Text(
                    'Keranjang ($_jumlahItem item)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RiwayatTransaksiScreen()),
                  ),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Riwayat'),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              shrinkWrap: true,
              itemCount: _keranjang.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = _keranjang.entries.elementAt(index);

                return _buildItemKeranjang(entry.key, entry.value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemKeranjang(int idBarang, int qty) {
    final barang = _barangById(idBarang);

    if (barang == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  barang.namaBarang,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('${formatRupiah(barang.hargaJual)} × $qty'),
                Text(
                  'Subtotal: ${formatRupiah(barang.hargaJual * qty)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Kurangi',
            onPressed: () => _ubahQty(idBarang, -1),
          ),
          Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Tambah',
            onPressed: () => _ubahQty(idBarang, 1),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Hapus item',
            onPressed: () => _hapusDariKeranjang(idBarang),
          ),
        ],
      ),
    );
  }

  /// Ringkasan pembayaran. Selalu terlihat di
  /// bagian bawah, termasuk saat keyboard muncul
  /// (Scaffold menyusutkan badan secara otomatis).
  Widget _buildRingkasanPembayaran() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8),
        ],
      ),
      child: SafeArea(
        // Padding navigasi sistem hanya diperlukan
        // saat keyboard tertutup. Saat keyboard
        // terbuka, area bawah sudah ditempati
        // keyboard sehingga menambahkannya hanya
        // membuang ruang dan mendorong overflow.
        top: false,
        bottom: MediaQuery.viewInsetsOf(context).bottom == 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$_jumlahItem item',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Text('Total'),
                  const SizedBox(width: 8),
                  Text(
                    formatRupiah(_total),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('input_bayar'),
                controller: _bayarController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Jumlah Pembayaran',
                  prefixIcon: const Icon(Icons.payments),
                  border: const OutlineInputBorder(),
                  hintText: formatRupiah(0),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Kembalian',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    formatRupiah(_kembalian),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _proses ? null : _prosesTransaksi,
                  icon: _proses
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_proses ? 'PROSES...' : 'BAYAR'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
