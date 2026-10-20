import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/barang.dart';
import '../models/pemasukan.dart';
import '../models/penjualan.dart';
import '../models/pengeluaran.dart';
import '../services/barang_service.dart';
import '../services/pemasukan_service.dart';
import '../services/penjualan_service.dart';
import '../services/pengeluaran_service.dart';
import '../screens/pemasukan_screen.dart';
import '../screens/pengeluaran_screen.dart';
import '../utils/kios_utils.dart';

/// Laporan penjualan, keuntungan, stok, pemasukan,
/// dan pengeluaran dari SQLite.
class LaporanScreen extends StatefulWidget {
  final PenjualanService penjualanService;
  final BarangService barangService;
  final PemasukanService pemasukanService;
  final PengeluaranService pengeluaranService;

  LaporanScreen({
    super.key,
    PenjualanService? penjualanService,
    BarangService? barangService,
    PemasukanService? pemasukanService,
    PengeluaranService? pengeluaranService,
  }) : penjualanService = penjualanService ?? PenjualanService(),
       barangService = barangService ?? BarangService(),
       pemasukanService = pemasukanService ?? PemasukanService(),
       pengeluaranService = pengeluaranService ?? PengeluaranService();

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

enum _Bagian { penjualan, keuntungan, stok, pemasukan, pengeluaran }

enum _Periode { hariIni, tujuhHari, tigaPuluhHari, semua }

class _LaporanScreenState extends State<LaporanScreen> {
  _Bagian _bagian = _Bagian.penjualan;
  _Periode _periode = _Periode.hariIni;

  List<Penjualan> _transaksi = [];
  Map<String, double> _ringkasan = {};
  List<Barang> _barang = [];
  List<Pemasukan> _pemasukan = [];
  List<Pengeluaran> _pengeluaran = [];
  Map<String, double> _chartData = {};

  bool _loading = false;
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
      final (awal, akhir) = _periodeRange();

      final hasil = await Future.wait([
        widget.penjualanService.getRiwayatPeriode(
          tanggalMulai: awal,
          tanggalSelesai: akhir,
        ),
        widget.penjualanService.ringkasanKeuntungan(
          tanggalMulai: awal,
          tanggalSelesai: akhir,
        ),
        widget.barangService.getAll(),
        widget.pemasukanService.getAll(),
        widget.pengeluaranService.getAll(),
        widget.penjualanService.penjualanPerHari(),
      ]);

      if (!mounted) return;

      setState(() {
        _transaksi = hasil[0] as List<Penjualan>;
        _ringkasan = hasil[1] as Map<String, double>;
        _barang = hasil[2] as List<Barang>;
        _pemasukan = hasil[3] as List<Pemasukan>;
        _pengeluaran = hasil[4] as List<Pengeluaran>;
        _chartData = hasil[5] as Map<String, double>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Gagal memuat laporan: $e';
      });
    }
  }

  (String, String?) _periodeRange() {
    switch (_periode) {
      case _Periode.hariIni:
        return (tanggalHariIni(), null);
      case _Periode.tujuhHari:
        final awal = DateTime.now().subtract(const Duration(days: 6));
        return (_keTanggal(awal), null);
      case _Periode.tigaPuluhHari:
        final awal = DateTime.now().subtract(const Duration(days: 29));
        return (_keTanggal(awal), null);
      case _Periode.semua:
        return ('2000-01-01', null);
    }
  }

  String _keTanggal(DateTime t) {
    return '${t.year.toString().padLeft(4, '0')}'
        '-${t.month.toString().padLeft(2, '0')}'
        '-${t.day.toString().padLeft(2, '0')}';
  }

  Future<void> _bukaHalaman(Widget halaman) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => halaman));

    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPilihanBagian(),
            const SizedBox(height: 12),
            if (_bagian == _Bagian.penjualan) ...[
              _buildPilihanPeriode(),
              const SizedBox(height: 12),
              if (_error.isNotEmpty)
                Center(child: Text(_error))
              else ...[
                _buildChart(),
                const SizedBox(height: 12),
                _buildRingkasanPenjualan(),
                const SizedBox(height: 12),
                _buildDaftarTransaksi(),
              ],
            ],
            if (_bagian == _Bagian.keuntungan) ...[
              _buildPilihanPeriode(),
              const SizedBox(height: 12),
              if (_error.isNotEmpty)
                Center(child: Text(_error))
              else
                _buildRingkasanKeuntungan(),
            ],
            if (_bagian == _Bagian.stok) ...[
              if (_error.isNotEmpty)
                Center(child: Text(_error))
              else
                _buildLaporanStok(),
            ],
            if (_bagian == _Bagian.pemasukan) ...[
              _buildHeaderPemasukan(),
              const SizedBox(height: 12),
              _buildDaftarPemasukan(),
            ],
            if (_bagian == _Bagian.pengeluaran) ...[
              _buildHeaderPengeluaran(),
              const SizedBox(height: 12),
              _buildDaftarPengeluaran(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPilihanBagian() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final bagian in _Bagian.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_labelBagian(bagian)),
                selected: _bagian == bagian,
                onSelected: (_) {
                  setState(() => _bagian = bagian);
                  _loadData();
                },
              ),
            ),
        ],
      ),
    );
  }

  String _labelBagian(_Bagian bagian) {
    switch (bagian) {
      case _Bagian.penjualan:
        return 'Penjualan';
      case _Bagian.keuntungan:
        return 'Keuntungan';
      case _Bagian.stok:
        return 'Stok';
      case _Bagian.pemasukan:
        return 'Pemasukan';
      case _Bagian.pengeluaran:
        return 'Pengeluaran';
    }
  }

  Widget _buildPilihanPeriode() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final periode in _Periode.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(_labelPeriode(periode)),
                onPressed: () {
                  setState(() => _periode = periode);
                  _loadData();
                },
              ),
            ),
        ],
      ),
    );
  }

  String _labelPeriode(_Periode periode) {
    switch (periode) {
      case _Periode.hariIni:
        return 'Hari Ini';
      case _Periode.tujuhHari:
        return '7 Hari';
      case _Periode.tigaPuluhHari:
        return '30 Hari';
      case _Periode.semua:
        return 'Semua';
    }
  }

  Widget _buildChart() {
    if (_chartData.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = _chartData.entries.toList();
    final maks = entries.fold(0.0, (nilai, e) => nilai + e.value);

    if (maks <= 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Penjualan Bersih 7 Hari Terakhir',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  maxY: maks,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  barGroups: [
                    for (var i = 0; i < entries.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: entries[i].value,
                            color: Theme.of(context).colorScheme.primary,
                            width: 12,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRingkasanPenjualan() {
    final totalPenjualan = _ringkasan['total_penjualan'] ?? 0;
    final totalRetur = _ringkasan['total_retur'] ?? 0;
    final penjualanBersih = _ringkasan['penjualan_bersih'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildRow('Total Penjualan', totalPenjualan),
            _buildRow('Total Retur', totalRetur),
            const Divider(),
            _buildRow(
              'Penjualan Bersih',
              penjualanBersih,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaftarTransaksi() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_transaksi.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Tidak ada transaksi.')),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          for (final transaksi in _transaksi)
            ListTile(
              dense: true,
              leading: const Icon(Icons.receipt_outlined),
              title: Text(
                transaksi.nomorTransaksi,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(formatDateTime(transaksi.tanggal)),
              trailing: Text(
                formatRupiah(transaksi.total),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRingkasanKeuntungan() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalPenjualan = _ringkasan['total_penjualan'] ?? 0;
    final totalRetur = _ringkasan['total_retur'] ?? 0;
    final penjualanBersih = _ringkasan['penjualan_bersih'] ?? 0;
    final keuntunganKotor = _ringkasan['keuntungan_kotor'] ?? 0;
    final pengeluaran = _ringkasan['pengeluaran'] ?? 0;
    final keuntunganBersih = _ringkasan['keuntungan_bersih'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildRow('Total Penjualan', totalPenjualan),
            _buildRow('Total Retur', totalRetur),
            _buildRow('Penjualan Bersih', penjualanBersih),
            _buildRow('Keuntungan Kotor', keuntunganKotor),
            _buildRow('Pengeluaran', pengeluaran),
            const Divider(),
            _buildRow('Keuntungan Bersih', keuntunganBersih, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, double nilai, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            formatRupiah(nilai),
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaporanStok() {
    final daftar = List<Barang>.from(_barang);

    daftar.sort((a, b) => a.stok.compareTo(b.stok));

    if (daftar.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Belum ada barang.')),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          for (final barang in daftar)
            ListTile(
              dense: true,
              leading: Icon(
                barang.stok <= barang.stokMinimum
                    ? Icons.warning_amber_outlined
                    : Icons.inventory_2_outlined,
                color: barang.stok <= barang.stokMinimum
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
              title: Text(
                barang.namaBarang,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Minimum ${barang.stokMinimum}'),
              trailing: Text(
                '${barang.stok} ${barang.satuan}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderPemasukan() {
    return Row(
      children: [
        Expanded(
          child: const Text(
            'Pemasukan',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        FilledButton.icon(
          onPressed: () => _bukaHalaman(PemasukanScreen()),
          icon: const Icon(Icons.add),
          label: const Text('Tambah'),
        ),
      ],
    );
  }

  Widget _buildDaftarPemasukan() {
    if (_pemasukan.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Belum ada pemasukan.')),
        ),
      );
    }

    final total = _pemasukan.fold(0.0, (nilai, p) => nilai + p.nominal);

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Pemasukan'),
                Text(
                  formatRupiah(total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final p in _pemasukan)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.arrow_downward),
                  title: Text(p.sumber),
                  subtitle: Text(
                    '${formatTanggal(p.tanggal)}'
                    '${p.keterangan != null ? ' · ${p.keterangan}' : ''}',
                  ),
                  trailing: Text(
                    formatRupiah(p.nominal),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderPengeluaran() {
    return Row(
      children: [
        Expanded(
          child: const Text(
            'Pengeluaran',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        FilledButton.icon(
          onPressed: () => _bukaHalaman(PengeluaranScreen()),
          icon: const Icon(Icons.add),
          label: const Text('Tambah'),
        ),
      ],
    );
  }

  Widget _buildDaftarPengeluaran() {
    if (_pengeluaran.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Belum ada pengeluaran.')),
        ),
      );
    }

    final total = _pengeluaran.fold(0.0, (nilai, p) => nilai + p.nominal);

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Pengeluaran'),
                Text(
                  formatRupiah(total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final p in _pengeluaran)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.arrow_upward),
                  title: Text(p.kategori),
                  subtitle: Text(
                    '${formatTanggal(p.tanggal)}'
                    '${p.keterangan != null ? ' · ${p.keterangan}' : ''}',
                  ),
                  trailing: Text(
                    formatRupiah(p.nominal),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
