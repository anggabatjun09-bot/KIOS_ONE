import 'package:flutter/material.dart';

import '../models/detail_penjualan.dart';
import '../models/penjualan.dart';
import '../models/retur.dart';
import '../services/penjualan_service.dart';
import '../services/retur_service.dart';
import '../utils/kios_utils.dart';
import 'riwayat_retur_screen.dart';

/// Alasan retur yang tersedia.
///
/// Tepat dua pilihan. Satu alasan
/// berlaku untuk seluruh barang
/// dalam satu proses retur.
const _alasanRetur = [alasanSalahBeli, alasanTidakLayak];

/// Halaman retur barang.
///
/// Satu halaman untuk memilih
/// transaksi penjualan asli dan
/// memproses retur satu atau lebih
/// barang sekaligus.
///
/// Nilai pengembalian dihitung
/// otomatis dari harga jual pada
/// transaksi asli, bukan harga
/// barang terbaru.
class ReturScreen extends StatefulWidget {
  final PenjualanService penjualanService;
  final ReturService returService;

  ReturScreen({
    super.key,
    PenjualanService? penjualanService,
    ReturService? returService,
  }) : penjualanService = penjualanService ?? PenjualanService(),
       returService = returService ?? ReturService();

  @override
  State<ReturScreen> createState() => _ReturScreenState();
}

class _ReturScreenState extends State<ReturScreen> {
  final TextEditingController _cariController =
      TextEditingController();

  List<Penjualan> _transaksi = [];
  List<Penjualan> _transaksiFilter = [];

  Penjualan? _transaksiTerpilih;
  List<_ItemReturForm> _items = [];

  String _alasan = alasanSalahBeli;

  bool _loadingTransaksi = true;
  bool _loadingDetail = false;
  String _error = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadTransaksi();
  }

  @override
  void dispose() {
    _cariController.dispose();
    super.dispose();
  }

  Future<void> _loadTransaksi() async {
    setState(() {
      _loadingTransaksi = true;
      _error = '';
    });

    try {
      final hasil = await widget.penjualanService.getRiwayat(
        limit: 100,
      );

      if (!mounted) return;

      setState(() {
        _transaksi = hasil;
        _transaksiFilter = hasil;
        _loadingTransaksi = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingTransaksi = false;
        _error = 'Gagal memuat transaksi: $e';
      });
    }
  }

  void _cari(String kata) {
    final kataKecil = kata.toLowerCase();

    setState(() {
      _transaksiFilter = _transaksi
          .where(
            (t) =>
                t.nomorTransaksi.toLowerCase().contains(
                  kataKecil,
                ),
          )
          .toList();
    });
  }

  Future<void> _pilihTransaksi(Penjualan transaksi) async {
    setState(() {
      _loadingDetail = true;
      _error = '';
    });

    try {
      final detail =
          await widget.penjualanService.getDetail(
            transaksi.idPenjualan!,
          );

      final items = <_ItemReturForm>[];

      for (final d in detail) {
        final sisa =
            await widget.returService
                .sisaDapatDikembalikan(d.idDetailPenjualan!);

        // Item yang sudah dikembalikan
        // seluruhnya tidak dapat
        // dipilih lagi.
        if (sisa > 0) {
          items.add(
            _ItemReturForm(
              detail: d,
              jumlahBeli: d.jumlah,
              sudahRetur: d.jumlah - sisa,
              sisa: sisa,
            ),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _transaksiTerpilih = transaksi;
        _items = items;
        _alasan = alasanSalahBeli;
        _loadingDetail = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingDetail = false;
      });

      _snackbar('Gagal memuat detail transaksi: $e');
    }
  }

  /// Kembali ke pemilihan transaksi.
  void _kembaliMemilihTransaksi() {
    setState(() {
      _transaksiTerpilih = null;
      _items = [];
    });
  }

  List<_ItemReturForm> get _itemTerpilih =>
      _items.where((item) => item.dipilih).toList();

  double get _totalPengembalian {
    var total = 0.0;

    for (final item in _itemTerpilih) {
      total += item.jumlah * item.detail.hargaJual;
    }

    return total;
  }

  Future<void> _simpan() async {
    final terpilih = _itemTerpilih;

    if (terpilih.isEmpty) {
      _snackbar('Pilih barang yang dikembalikan.');
      return;
    }

    // Pastikan jumlah retur setiap
    // item yang dicentang valid.
    for (final item in terpilih) {
      if (item.jumlah <= 0 || item.jumlah > item.sisa) {
        _snackbar(
          'Jumlah retur tidak valid untuk '
          '${item.detail.namaBarang ?? 'barang'}.',
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final retur = await widget.returService.simpanRetur(
        idPenjualan: _transaksiTerpilih!.idPenjualan!,
        items: [
          for (final item in terpilih)
            ItemRetur(
              idDetailPenjualan: item.detail.idDetailPenjualan!,
              idBarang: item.detail.idBarang,
              jumlah: item.jumlah,
              // Harga dari transaksi asli.
              hargaSatuan: item.detail.hargaJual,
              alasan: _alasan,
            ),
        ],
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Retur Tersimpan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nomor: ${retur.nomorRetur}'),
              const SizedBox(height: 8),
              Text(
                'Item: ${terpilih.length}',
              ),
              const SizedBox(height: 8),
              Text(
                'Nilai pengembalian: '
                '${formatRupiah(retur.totalNilai)}',
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      _snackbar('Gagal menyimpan retur: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _snackbar(String pesan) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(pesan)),
    );
  }

  Future<void> _bukaRiwayatRetur() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RiwayatReturScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Retur Barang'),
        actions: [
          IconButton(
            tooltip: 'Riwayat Retur',
            onPressed: _bukaRiwayatRetur,
            icon: const Icon(Icons.history_outlined),
          ),
        ],
      ),
      body: _transaksiTerpilih == null
          ? _buildPilihTransaksi()
          : _buildFormRetur(),
      bottomNavigationBar:
          _transaksiTerpilih == null
              ? null
              : _buildFooter(),
    );
  }

  // ----------------------------------------------------------------
  // Pemilihan transaksi penjualan asli.
  // ----------------------------------------------------------------

  Widget _buildPilihTransaksi() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _cariController,
            decoration: const InputDecoration(
              hintText: 'Cari nomor transaksi',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: _cari,
          ),
        ),
        Expanded(child: _buildDaftarTransaksi()),
      ],
    );
  }

  Widget _buildDaftarTransaksi() {
    if (_loadingTransaksi) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_transaksiFilter.isEmpty) {
      return const Center(child: Text('Belum ada transaksi.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _transaksiFilter.length,
      itemBuilder: (context, index) {
        final transaksi = _transaksiFilter[index];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.receipt_outlined),
            ),
            title: Text(
              transaksi.nomorTransaksi,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(formatDateTime(transaksi.tanggal)),
            trailing: Text(
              formatRupiah(transaksi.total),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () => _pilihTransaksi(transaksi),
          ),
        );
      },
    );
  }

  // ----------------------------------------------------------------
  // Form retur multi-item.
  // ----------------------------------------------------------------

  Widget _buildFormRetur() {
    if (_loadingDetail) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Semua item pada transaksi ini '
                'sudah dikembalikan.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _kembaliMemilihTransaksi,
                child: const Text('PILIH TRANSAKSI LAIN'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoTransaksi(),
        const SizedBox(height: 16),
        _buildDaftarBarang(),
        const SizedBox(height: 16),
        _buildAlasan(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInfoTransaksi() {
    final t = _transaksiTerpilih!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.nomorTransaksi,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _kembaliMemilihTransaksi,
                  child: const Text('GANTI'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              formatDateTime(t.tanggal),
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
            const Divider(),
            _buildRow('Total Penjualan', formatRupiah(t.total)),
          ],
        ),
      ),
    );
  }

  Widget _buildDaftarBarang() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Pilih barang yang dikembalikan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final item in _items)
              _buildItemBarang(item),
          ],
        ),
      ),
    );
  }

  Widget _buildItemBarang(_ItemReturForm item) {
    final d = item.detail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CheckboxListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8),
          title: Text(
            d.namaBarang ?? 'Barang #${d.idBarang}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (d.kodeBarang != null) ...[
                Text(d.kodeBarang!),
                const SizedBox(height: 2),
              ],
              Text(
                'Harga jual: ${formatRupiah(d.hargaJual)}',
              ),
              Text(
                'Dibeli: ${item.jumlahBeli} · '
                'Sudah retur: ${item.sudahRetur} · '
                'Sisa: ${item.sisa}',
              ),
            ],
          ),
          value: item.dipilih,
          onChanged: (nilai) {
            setState(() {
              item.dipilih = nilai ?? false;

              // Default jumlah retur 1
              // untuk barang baru dicentang.
              if (item.dipilih && item.jumlah == 0) {
                item.jumlah = 1;
              }
            });
          },
        ),
        if (item.dipilih)
          Padding(
            padding: const EdgeInsets.only(
              left: 48,
              right: 16,
              bottom: 8,
            ),
            child: Row(
              children: [
                const Expanded(child: Text('Jumlah Retur')),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Kurangi',
                  onPressed: item.jumlah <= 1
                      ? null
                      : () => setState(() => item.jumlah--),
                ),
                Text(
                  '${item.jumlah}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Tambah',
                  onPressed: item.jumlah >= item.sisa
                      ? null
                      : () => setState(() => item.jumlah++),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildAlasan() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alasan Retur',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final alasan in _alasanRetur)
                  ChoiceChip(
                    label: Text(alasan),
                    selected: _alasan == alasan,
                    onSelected: (_) =>
                        setState(() => _alasan = alasan),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _alasan == alasanTidakLayak
                  ? 'Tidak layak: stok siap jual tidak '
                    'bertambah dan biaya barang '
                    'menjadi kerugian.'
                  : 'Salah beli: barang layak dijual '
                    'kembali dan stok bertambah '
                    'setelah retur.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Total Pengembalian',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      formatRupiah(_totalPengembalian),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _simpan,
                icon: _saving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.assignment_return),
                label: Text(
                  _saving ? 'MENYIMPAN...' : 'SIMPAN RETUR',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String nilai) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Flexible(
            child: Text(
              nilai,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Data satu item transaksi
/// yang masih dapat dikembalikan.
class _ItemReturForm {
  final DetailPenjualan detail;
  final int jumlahBeli;
  final int sudahRetur;
  final int sisa;

  bool dipilih = false;
  int jumlah = 0;

  _ItemReturForm({
    required this.detail,
    required this.jumlahBeli,
    required this.sudahRetur,
    required this.sisa,
  });
}
