class Pengeluaran {
  final int? idPengeluaran;
  final String tanggal;
  final String kategori;
  final double nominal;
  final String? keterangan;

  const Pengeluaran({
    this.idPengeluaran,
    required this.tanggal,
    required this.kategori,
    required this.nominal,
    this.keterangan,
  });

  factory Pengeluaran.fromMap(Map<String, Object?> map) {
    return Pengeluaran(
      idPengeluaran: map['id_pengeluaran'] as int?,
      tanggal: map['tanggal'] as String,
      kategori: map['kategori'] as String,
      nominal: (map['nominal'] as num).toDouble(),
      keterangan: map['keterangan'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id_pengeluaran': idPengeluaran,
      'tanggal': tanggal,
      'kategori': kategori,
      'nominal': nominal,
      'keterangan': keterangan,
    };
  }
}
