class DetailPenjualan {
  final int? idDetailPenjualan;
  final int idPenjualan;
  final int idBarang;
  final int jumlah;
  final double hargaJual;
  final double hargaBeli;
  final double subtotal;
  final double keuntungan;

  /// Nama dan kode barang (dari JOIN, opsional).
  final String? namaBarang;
  final String? kodeBarang;

  const DetailPenjualan({
    this.idDetailPenjualan,
    required this.idPenjualan,
    required this.idBarang,
    required this.jumlah,
    required this.hargaJual,
    required this.hargaBeli,
    required this.subtotal,
    required this.keuntungan,
    this.namaBarang,
    this.kodeBarang,
  });

  factory DetailPenjualan.fromMap(Map<String, Object?> map) {
    return DetailPenjualan(
      idDetailPenjualan: map['id_detail_penjualan'] as int?,
      idPenjualan: map['id_penjualan'] as int,
      idBarang: map['id_barang'] as int,
      jumlah: map['jumlah'] as int,
      hargaJual: (map['harga_jual'] as num).toDouble(),
      hargaBeli: (map['harga_beli'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
      keuntungan: (map['keuntungan'] as num).toDouble(),
      namaBarang: map['nama_barang'] as String?,
      kodeBarang: map['kode_barang'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id_detail_penjualan': idDetailPenjualan,
      'id_penjualan': idPenjualan,
      'id_barang': idBarang,
      'jumlah': jumlah,
      'harga_jual': hargaJual,
      'harga_beli': hargaBeli,
      'subtotal': subtotal,
      'keuntungan': keuntungan,
    };
  }
}
