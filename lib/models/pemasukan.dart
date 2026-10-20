class Pemasukan {
  final int? idPemasukan;
  final String tanggal;
  final String sumber;
  final double nominal;
  final String? keterangan;

  const Pemasukan({
    this.idPemasukan,
    required this.tanggal,
    required this.sumber,
    required this.nominal,
    this.keterangan,
  });

  factory Pemasukan.fromMap(Map<String, Object?> map) {
    return Pemasukan(
      idPemasukan: map['id_pemasukan'] as int?,
      tanggal: map['tanggal'] as String,
      sumber: map['sumber'] as String,
      nominal: (map['nominal'] as num).toDouble(),
      keterangan: map['keterangan'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id_pemasukan': idPemasukan,
      'tanggal': tanggal,
      'sumber': sumber,
      'nominal': nominal,
      'keterangan': keterangan,
    };
  }
}
