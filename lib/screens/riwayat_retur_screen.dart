import 'package:flutter/material.dart';

import '../models/retur.dart';
import '../services/retur_service.dart';
import '../utils/kios_utils.dart';

/// Riwayat retur barang dan detailnya.
class RiwayatReturScreen extends StatefulWidget {
  final ReturService returService;

  RiwayatReturScreen({super.key, ReturService? returService})
    : returService = returService ?? ReturService();

  @override
  State<RiwayatReturScreen> createState() => _RiwayatReturScreenState();
}

class _RiwayatReturScreenState extends State<RiwayatReturScreen> {
  List<Retur> _retur = [];
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
      final hasil = await widget.returService.getRiwayat();

      if (!mounted) return;

      setState(() {
        _retur = hasil;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Gagal memuat retur: $e';
      });
    }
  }

  Future<void> _bukaDetail(Retur retur) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailReturScreen(
          idRetur: retur.idRetur!,
          returService: widget.returService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Retur')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading && _retur.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
            ? Center(child: Text(_error))
            : _retur.isEmpty
            ? const Center(child: Text('Belum ada retur.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _retur.length,
                itemBuilder: (context, index) {
                  final retur = _retur[index];

                  return _buildItem(retur);
                },
              ),
      ),
    );
  }

  Widget _buildItem(Retur retur) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: const CircleAvatar(
          child: Icon(Icons.assignment_return_outlined),
        ),
        title: Text(
          retur.nomorRetur,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Transaksi: ${retur.nomorTransaksi ?? '-'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(formatDateTime(retur.tanggal)),
            if (retur.catatan != null && retur.catatan!.isNotEmpty)
              Text(
                retur.catatan!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Text(
          formatRupiah(retur.totalNilai),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onTap: () => _bukaDetail(retur),
      ),
    );
  }
}

/// Detail satu retur: daftar item yang dikembalikan.
class DetailReturScreen extends StatefulWidget {
  final int idRetur;
  final ReturService returService;

  const DetailReturScreen({
    super.key,
    required this.idRetur,
    required this.returService,
  });

  @override
  State<DetailReturScreen> createState() => _DetailReturScreenState();
}

class _DetailReturScreenState extends State<DetailReturScreen> {
  Retur? _retur;
  List<DetailRetur> _detail = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final retur = await widget.returService.getById(widget.idRetur);
    final detail = await widget.returService.getDetail(widget.idRetur);

    if (!mounted) return;

    setState(() {
      _retur = retur;
      _detail = detail;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Retur')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _retur == null
          ? const Center(child: Text('Retur tidak ditemukan.'))
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
                          _retur!.nomorRetur,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Transaksi: ${_retur!.nomorTransaksi ?? '-'}',
                        ),
                        Text(formatDateTime(_retur!.tanggal)),
                        const Divider(),
                        _buildRow(
                          'Nilai Pengembalian',
                          formatRupiah(_retur!.totalNilai),
                          bold: true,
                        ),
                        if (_retur!.catatan != null &&
                            _retur!.catatan!.isNotEmpty)
                          _buildRow('Catatan', _retur!.catatan!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Item Retur',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${item.jumlah} × '
                                '${formatRupiah(item.hargaSatuan)}',
                              ),
                              Text(
                                'Kondisi: '
                                '${item.kondisiLayak ? 'Layak Jual Kembali' : 'Rusak'}',
                                style: TextStyle(
                                  color: item.kondisiLayak
                                      ? null
                                      : Theme.of(context).colorScheme.error,
                                ),
                              ),
                              if (item.alasan.isNotEmpty)
                                Text('Alasan: ${item.alasan}'),
                            ],
                          ),
                          trailing: Text(
                            formatRupiah(item.subtotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          Flexible(
            child: Text(
              nilai,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
