import 'package:flutter/material.dart';

import '../models/detail_penjualan.dart';
import '../models/penjualan.dart';
import '../services/penjualan_service.dart';
import '../utils/kios_utils.dart';
import 'struk_preview_screen.dart';

/// Riwayat dan detail transaksi penjualan.
class RiwayatTransaksiScreen extends StatefulWidget {
  final PenjualanService penjualanService;

  RiwayatTransaksiScreen({super.key, PenjualanService? penjualanService})
    : penjualanService = penjualanService ?? PenjualanService();

  @override
  State<RiwayatTransaksiScreen> createState() => _RiwayatTransaksiScreenState();
}

class _RiwayatTransaksiScreenState extends State<RiwayatTransaksiScreen> {
  List<Penjualan> _transaksi = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final hasil = await widget.penjualanService.getRiwayat();

      if (!mounted) return;

      setState(() {
        _transaksi = hasil;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Gagal memuat transaksi: $e';
      });
    }
  }

  Future<void> _bukaDetail(Penjualan transaksi) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailTransaksiScreen(
          idPenjualan: transaksi.idPenjualan!,
          penjualanService: widget.penjualanService,
        ),
      ),
    );
  }

  /// Membuka struk PDF transaksi.
  ///
  /// Hanya membaca transaksi yang sudah
  /// tersimpan, tidak membuat transaksi
  /// baru atau mengubah data.
  Future<void> _bukaStruk(Penjualan transaksi) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StrukPreviewScreen(
          idPenjualan: transaksi.idPenjualan!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading && _transaksi.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
            ? Center(child: Text(_error))
            : _transaksi.isEmpty
            ? const Center(child: Text('Belum ada transaksi.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _transaksi.length,
                itemBuilder: (context, index) {
                  final transaksi = _transaksi[index];

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.receipt_outlined),
                      ),
                      title: Text(
                        transaksi.nomorTransaksi,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(formatDateTime(transaksi.tanggal)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatRupiah(transaksi.total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Kbl ${formatRupiah(transaksi.kembalian)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.receipt_long_outlined),
                            tooltip: 'Lihat Struk PDF',
                            onPressed: () => _bukaStruk(transaksi),
                          ),
                        ],
                      ),
                      onTap: () => _bukaDetail(transaksi),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Detail satu transaksi: daftar item dan ringkasan.
class DetailTransaksiScreen extends StatefulWidget {
  final int idPenjualan;
  final PenjualanService penjualanService;

  const DetailTransaksiScreen({
    super.key,
    required this.idPenjualan,
    required this.penjualanService,
  });

  @override
  State<DetailTransaksiScreen> createState() =>
      _DetailTransaksiScreenState();
}

class _DetailTransaksiScreenState extends State<DetailTransaksiScreen> {
  Penjualan? _transaksi;
  List<DetailPenjualan> _detail = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final transaksi = await widget.penjualanService.getById(widget.idPenjualan);
    final detail = await widget.penjualanService.getDetail(widget.idPenjualan);

    if (!mounted) return;

    setState(() {
      _transaksi = transaksi;
      _detail = detail;
      _loading = false;
    });
  }

  /// Membuka struk PDF transaksi ini.
  Future<void> _bukaStruk() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StrukPreviewScreen(
          idPenjualan: widget.idPenjualan,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Transaksi'),
        actions: [
          IconButton(
            tooltip: 'Lihat Struk PDF',
            onPressed: _bukaStruk,
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _transaksi == null
          ? const Center(child: Text('Transaksi tidak ditemukan.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _transaksi!.nomorTransaksi,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(formatDateTime(_transaksi!.tanggal)),
                        const Divider(),
                        _buildRow('Total', formatRupiah(_transaksi!.total)),
                        _buildRow('Bayar', formatRupiah(_transaksi!.bayar)),
                        _buildRow(
                          'Kembalian',
                          formatRupiah(_transaksi!.kembalian),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Item Terjual',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (final item in _detail)
                        ListTile(
                          dense: true,
                          title: Text(
                            item.namaBarang ?? 'Barang #${item.idBarang}',
                          ),
                          subtitle: Text(
                            '${item.jumlah} × '
                            '${formatRupiah(item.hargaJual)}'
                            ' · untung '
                            '${formatRupiah(item.keuntungan)}',
                          ),
                          trailing: Text(
                            formatRupiah(item.subtotal),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRow(String label, String nilai, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            nilai,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
