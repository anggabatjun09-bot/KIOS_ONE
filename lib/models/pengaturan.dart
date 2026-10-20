class Pengaturan {
  final int? idPengaturan;
  final String namaKios;
  final String namaPemilik;
  final String alamat;
  final String nomorTelepon;

  const Pengaturan({
    this.idPengaturan,
    required this.namaKios,
    required this.namaPemilik,
    required this.alamat,
    required this.nomorTelepon,
  });

  factory Pengaturan.fromMap(Map<String, Object?> map) {
    return Pengaturan(
      idPengaturan: map['id_pengaturan'] as int?,
      namaKios: map['nama_kios'] as String,
      namaPemilik: map['nama_pemilik'] as String,
      alamat: map['alamat'] as String,
      nomorTelepon: map['nomor_telepon'] as String,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id_pengaturan': idPengaturan,
      'nama_kios': namaKios,
      'nama_pemilik': namaPemilik,
      'alamat': alamat,
      'nomor_telepon': nomorTelepon,
    };
  }
}
