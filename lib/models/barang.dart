class Barang {
  final int? idBarang;
  final String kodeBarang;
  final String namaBarang;
  final int? idKategori;
  final String satuan;
  final double hargaBeli;
  final double hargaJual;
  final int stok;
  final int stokMinimum;

  /// Path relatif foto terhadap direktori dokumen aplikasi
  /// (contoh: `foto_barang/photo_123.jpg`). Null jika tanpa foto.
  final String? foto;
  final String createdAt;
  final String updatedAt;

  const Barang({
    this.idBarang,
    required this.kodeBarang,
    required this.namaBarang,
    this.idKategori,
    required this.satuan,
    this.hargaBeli = 0,
    this.hargaJual = 0,
    this.stok = 0,
    this.stokMinimum = 5,
    this.foto,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Barang.fromMap(Map<String, Object?> map) {
    return Barang(
      idBarang: map['id_barang'] as int?,
      kodeBarang: map['kode_barang'] as String,
      namaBarang: map['nama_barang'] as String,
      idKategori: map['id_kategori'] as int?,
      satuan: map['satuan'] as String,
      hargaBeli: (map['harga_beli'] as num).toDouble(),
      hargaJual: (map['harga_jual'] as num).toDouble(),
      stok: map['stok'] as int,
      stokMinimum: map['stok_minimum'] as int,
      foto: map['foto'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id_barang': idBarang,
      'kode_barang': kodeBarang,
      'nama_barang': namaBarang,
      'id_kategori': idKategori,
      'satuan': satuan,
      'harga_beli': hargaBeli,
      'harga_jual': hargaJual,
      'stok': stok,
      'stok_minimum': stokMinimum,
      'foto': foto,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Barang copyWith({
    int? idBarang,
    String? kodeBarang,
    String? namaBarang,
    int? idKategori,
    String? satuan,
    double? hargaBeli,
    double? hargaJual,
    int? stok,
    int? stokMinimum,
    String? foto,
    String? createdAt,
    String? updatedAt,
  }) {
    return Barang(
      idBarang: idBarang ?? this.idBarang,
      kodeBarang: kodeBarang ?? this.kodeBarang,
      namaBarang: namaBarang ?? this.namaBarang,
      idKategori: idKategori ?? this.idKategori,
      satuan: satuan ?? this.satuan,
      hargaBeli: hargaBeli ?? this.hargaBeli,
      hargaJual: hargaJual ?? this.hargaJual,
      stok: stok ?? this.stok,
      stokMinimum: stokMinimum ?? this.stokMinimum,
      foto: foto ?? this.foto,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
