class Penjualan {
  final int? idPenjualan;
  final String nomorTransaksi;
  final String tanggal;
  final double total;
  final double bayar;
  final double kembalian;
  final int? idUser;

  const Penjualan({
    this.idPenjualan,
    required this.nomorTransaksi,
    required this.tanggal,
    required this.total,
    required this.bayar,
    required this.kembalian,
    this.idUser,
  });

  factory Penjualan.fromMap(Map<String, Object?> map) {
    return Penjualan(
      idPenjualan: map['id_penjualan'] as int?,
      nomorTransaksi: map['nomor_transaksi'] as String,
      tanggal: map['tanggal'] as String,
      total: (map['total'] as num).toDouble(),
      bayar: (map['bayar'] as num).toDouble(),
      kembalian: (map['kembalian'] as num).toDouble(),
      idUser: map['id_user'] as int?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id_penjualan': idPenjualan,
      'nomor_transaksi': nomorTransaksi,
      'tanggal': tanggal,
      'total': total,
      'bayar': bayar,
      'kembalian': kembalian,
      'id_user': idUser,
    };
  }
}
