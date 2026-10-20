class StokMasuk {
  final int? idStokMasuk;
  final int idBarang;
  final String tanggal;
  final int jumlah;
  final double hargaBeli;
  final double subtotal;
  final String? keterangan;

  /// Nama barang (dari JOIN, opsional).
  final String? namaBarang;

  const StokMasuk({
    this.idStokMasuk,
    required this.idBarang,
    required this.tanggal,
    required this.jumlah,
    required this.hargaBeli,
    required this.subtotal,
    this.keterangan,
    this.namaBarang,
  });

  factory StokMasuk.fromMap(Map<String, Object?> map) {
    return StokMasuk(
      idStokMasuk: map['id_stok_masuk'] as int?,
      idBarang: map['id_barang'] as int,
      tanggal: map['tanggal'] as String,
      jumlah: map['jumlah'] as int,
      hargaBeli: (map['harga_beli'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
      keterangan: map['keterangan'] as String?,
      namaBarang: map['nama_barang'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id_stok_masuk': idStokMasuk,
      'id_barang': idBarang,
      'tanggal': tanggal,
      'jumlah': jumlah,
      'harga_beli': hargaBeli,
      'subtotal': subtotal,
      'keterangan': keterangan,
    };
  }
}
