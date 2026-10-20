/// Gaya tampilan satu baris pada struk.
enum GayaStruk {
  /// Nama toko: rata tengah dan tebal.
  judul,

  /// Alamat/telepon toko: rata tengah, kecil.
  subjudul,

  /// Informasi transaksi: rata kiri.
  teks,

  /// Nilai penting (total): tebal.
  tebal,

  /// Garis pemisah.
  garis,

  /// Baris kosong.
  spasi,
}

/// Satu baris teks pada struk.
class StrukBaris {
  /// Teks bagian kiri.
  final String kiri;

  /// Teks bagian kanan (nilai rupiah).
  final String kanan;

  final GayaStruk gaya;

  const StrukBaris({
    this.kiri = '',
    this.kanan = '',
    this.gaya = GayaStruk.teks,
  });
}

/// Satu item barang pada struk.
///
/// Semua nilai diambil dari tabel
/// detail_penjualan yang tersimpan,
/// bukan dihitung ulang.
class ItemStruk {
  final String namaBarang;
  final int jumlah;
  final double hargaSatuan;
  final double subtotal;

  const ItemStruk({
    required this.namaBarang,
    required this.jumlah,
    required this.hargaSatuan,
    required this.subtotal,
  });
}

/// Data struk dari satu transaksi
/// penjualan yang sudah tersimpan.
///
/// Struk dibuat dari data ini saja,
/// sehingga membuat atau membuka struk
/// tidak pernah mengubah transaksi,
/// stok, pembayaran, maupun laporan.
class StrukData {
  /// Nama toko dari pengaturan, jika ada.
  final String? namaToko;

  /// Alamat toko dari pengaturan.
  final String alamat;

  /// Nomor telepon toko dari pengaturan.
  final String telepon;

  /// Nomor transaksi asli.
  final String nomorTransaksi;

  /// Tanggal transaksi (ISO).
  final String tanggal;

  /// Nama kasir, jika tersimpan pada transaksi.
  final String? namaKasir;

  /// Item barang dari detail penjualan.
  final List<ItemStruk> items;

  /// Total penjualan sesuai database.
  final double total;

  /// Uang yang diterima sesuai database.
  final double bayar;

  /// Kembalian sesuai database.
  final double kembalian;

  const StrukData({
    required this.nomorTransaksi,
    required this.tanggal,
    required this.items,
    required this.total,
    required this.bayar,
    required this.kembalian,
    this.namaToko,
    this.alamat = '',
    this.telepon = '',
    this.namaKasir,
  });

  /// Total jumlah barang pada struk.
  int get jumlahItem {
    var jumlah = 0;

    for (final item in items) {
      jumlah += item.jumlah;
    }

    return jumlah;
  }

  /// Nama file PDF untuk struk.
  String get namaFile => 'struk_$nomorTransaksi.pdf';
}
