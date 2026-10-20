/// Kondisi barang yang dikembalikan.
enum KondisiRetur {
  /// Layak dijual kembali. Stok siap jual bertambah.
  layak,

  /// Tidak layak dijual kembali. Stok siap jual tidak bertambah.
  rusak,
}

/// Alasan retur: salah beli.
///
/// Barang dianggap layak dijual
/// kembali dan stok bertambah
/// setelah retur berhasil.
const alasanSalahBeli = 'Salah beli';

/// Alasan retur: tidak layak.
///
/// Barang dianggap rusak/tidak layak
/// dijual kembali dan stok siap jual
/// tidak bertambah.
const alasanTidakLayak = 'Tidak layak';

/// Retur barang: pengembalian satu atau lebih item
/// dari satu transaksi penjualan.
class Retur {
  final int? idRetur;
  final String nomorRetur;
  final int idPenjualan;
  final String tanggal;
  final double totalNilai;
  final String? catatan;

  /// Nomor transaksi asli (dari JOIN, opsional).
  final String? nomorTransaksi;

  const Retur({
    this.idRetur,
    required this.nomorRetur,
    required this.idPenjualan,
    required this.tanggal,
    required this.totalNilai,
    this.catatan,
    this.nomorTransaksi,
  });

  factory Retur.fromMap(Map<String, Object?> map) {
    return Retur(
      idRetur: map['id_retur'] as int?,
      nomorRetur: map['nomor_retur'] as String,
      idPenjualan: map['id_penjualan'] as int,
      tanggal: map['tanggal'] as String,
      totalNilai: (map['total_nilai'] as num).toDouble(),
      catatan: map['catatan'] as String?,
      nomorTransaksi: map['nomor_transaksi'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id_retur': idRetur,
      'nomor_retur': nomorRetur,
      'id_penjualan': idPenjualan,
      'tanggal': tanggal,
      'total_nilai': totalNilai,
      'catatan': catatan,
    };
  }
}

/// Detail satu item retur.
class DetailRetur {
  final int? idDetailRetur;
  final int idRetur;
  final int idDetailPenjualan;
  final int idBarang;
  final int jumlah;
  final double hargaSatuan;
  final double subtotal;
  final String alasan;

  /// 'layak' atau 'rusak'.
  final String kondisi;

  /// Nama dan kode barang (dari JOIN, opsional).
  final String? namaBarang;
  final String? kodeBarang;

  const DetailRetur({
    this.idDetailRetur,
    required this.idRetur,
    required this.idDetailPenjualan,
    required this.idBarang,
    required this.jumlah,
    required this.hargaSatuan,
    required this.subtotal,
    required this.alasan,
    required this.kondisi,
    this.namaBarang,
    this.kodeBarang,
  });

  bool get kondisiLayak => kondisi == 'layak';

  factory DetailRetur.fromMap(Map<String, Object?> map) {
    return DetailRetur(
      idDetailRetur: map['id_detail_retur'] as int?,
      idRetur: map['id_retur'] as int,
      idDetailPenjualan: map['id_detail_penjualan'] as int,
      idBarang: map['id_barang'] as int,
      jumlah: map['jumlah'] as int,
      hargaSatuan: (map['harga_satuan'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
      alasan: map['alasan'] as String,
      kondisi: map['kondisi'] as String,
      namaBarang: map['nama_barang'] as String?,
      kodeBarang: map['kode_barang'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id_detail_retur': idDetailRetur,
      'id_retur': idRetur,
      'id_detail_penjualan': idDetailPenjualan,
      'id_barang': idBarang,
      'jumlah': jumlah,
      'harga_satuan': hargaSatuan,
      'subtotal': subtotal,
      'alasan': alasan,
      'kondisi': kondisi,
    };
  }
}

/// Item retur yang dimasukkan pengguna.
class ItemRetur {
  final int idDetailPenjualan;
  final int idBarang;
  final int jumlah;
  final double hargaSatuan;
  final String alasan;
  final KondisiRetur kondisi;

  ItemRetur({
    required this.idDetailPenjualan,
    required this.idBarang,
    required this.jumlah,
    required this.hargaSatuan,
    this.alasan = '',
    KondisiRetur? kondisi,
  }) : kondisi = _kondisiDariAlasan(alasan, kondisi);

  double get subtotal => jumlah * hargaSatuan;

  /// Kondisi barang diturunkan dari
  /// alasan retur:
  /// - [alasanSalahBeli]: layak dijual
  ///   kembali, stok bertambah.
  /// - [alasanTidakLayak]: rusak/tidak
  ///   layak, stok tidak bertambah.
  ///
  /// Alasan lain (misalnya data lama)
  /// mengikuti kondisi yang diberikan,
  /// atau layak jika tidak diberikan.
  static KondisiRetur _kondisiDariAlasan(
    String alasan,
    KondisiRetur? kondisi,
  ) {
    if (alasan == alasanSalahBeli) {
      return KondisiRetur.layak;
    }

    if (alasan == alasanTidakLayak) {
      return KondisiRetur.rusak;
    }

    return kondisi ?? KondisiRetur.layak;
  }
}
