class Kategori {
  final int? idKategori;
  final String namaKategori;

  const Kategori({this.idKategori, required this.namaKategori});

  factory Kategori.fromMap(Map<String, Object?> map) {
    return Kategori(
      idKategori: map['id_kategori'] as int?,
      namaKategori: map['nama_kategori'] as String,
    );
  }

  Map<String, Object?> toMap() {
    return {'id_kategori': idKategori, 'nama_kategori': namaKategori};
  }
}
