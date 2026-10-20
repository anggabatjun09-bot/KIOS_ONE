import '../models/barang.dart';
import '../models/penjualan.dart';
import '../services/barang_service.dart';
import '../services/penjualan_service.dart';
import '../services/pengeluaran_service.dart';
import '../utils/kios_utils.dart';

/// Ringkasan data dashboard untuk hari ini.
class DashboardRingkasan {
  /// Penjualan bersih: penjualan kotor
  /// dikurangi total nilai retur.
  final double penjualan;

  /// Total nilai retur hari ini.
  final double totalRetur;

  final int jumlahTransaksi;
  final double keuntungan;
  final double pengeluaran;

  const DashboardRingkasan({
    required this.penjualan,
    required this.totalRetur,
    required this.jumlahTransaksi,
    required this.keuntungan,
    required this.pengeluaran,
  });
}

/// Menghitung tanggal besok (awal hari berikutnya).
String _tanggalBesok(String tanggalHariIni) {
  final date = DateTime.parse(tanggalHariIni);
  final nextDay = date.add(const Duration(days: 1));
  return '${nextDay.year.toString().padLeft(4, '0')}-${nextDay.month.toString().padLeft(2, '0')}-${nextDay.day.toString().padLeft(2, '0')}';
}

/// Mengambil data ringkasan untuk dashboard.
class DashboardService {
  final PenjualanService penjualanService;
  final BarangService barangService;
  final PengeluaranService pengeluaranService;

  DashboardService({
    PenjualanService? penjualanService,
    BarangService? barangService,
    PengeluaranService? pengeluaranService,
  }) : penjualanService = penjualanService ?? PenjualanService(),
       barangService = barangService ?? BarangService(),
       pengeluaranService = pengeluaranService ?? PengeluaranService();

  Future<DashboardRingkasan> ringkasanHariIni() async {
    final awalHari = tanggalHariIni();
    final awalBesok = _tanggalBesok(awalHari);

    final transaksi = await penjualanService.getRiwayatPeriode(
      tanggalMulai: awalHari,
      tanggalSelesai: awalBesok,
    );

    final ringkasan = await penjualanService.ringkasanKeuntungan(
      tanggalMulai: awalHari,
      tanggalSelesai: awalBesok,
    );

    final pengeluaran = await pengeluaranService.totalPeriode(
      tanggalMulai: awalHari,
      tanggalSelesai: awalBesok,
    );

    return DashboardRingkasan(
      // Penjualan bersih: kotor - retur.
      penjualan: ringkasan['penjualan_bersih'] ?? 0,
      totalRetur: ringkasan['total_retur'] ?? 0,
      jumlahTransaksi: transaksi.length,
      // Keuntungan sudah disesuaikan retur,
      // lalu dikurangi pengeluaran.
      keuntungan: (ringkasan['keuntungan_kotor'] ?? 0) -
          pengeluaran,
      pengeluaran: pengeluaran,
    );
  }

  Future<List<Barang>> stokPerluDiperhatikan() async {
    final semua = await barangService.getAll();

    final daftar = semua.where((b) => b.stok <= b.stokMinimum).toList();

    daftar.sort((a, b) => a.stok.compareTo(b.stok));

    return daftar;
  }

  Future<List<Penjualan>> transaksiTerbaru({int limit = 5}) async {
    return penjualanService.getRiwayat(limit: limit);
  }
}
