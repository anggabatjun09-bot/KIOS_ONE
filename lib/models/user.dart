/// Peran pengguna.
///
/// Indeks enum digunakan untuk membandingkan
/// level akses: kasir < admin.
enum Role { kasir, admin }

/// Pengguna aplikasi.
///
/// Password tidak pernah disimpan di model
/// ini maupun di session.
class User {
  final int? idUser;
  final String username;
  final String nama;
  final Role role;
  final String createdAt;

  /// Hash PIN (`salt:iterasi:hash`).
  /// Null jika akun belum mempunyai PIN.
  /// Tidak pernah berisi PIN asli.
  final String? pinHash;

  const User({
    this.idUser,
    required this.username,
    required this.nama,
    required this.role,
    required this.createdAt,
    this.pinHash,
  });

  factory User.fromMap(Map<String, Object?> map) {
    final role = map['role'] as String? ?? Role.kasir.name;

    return User(
      idUser: map['id_user'] as int?,
      username: map['username'] as String,
      nama: map['nama'] as String,
      role: Role.values.asNameMap()[role] ?? Role.kasir,
      createdAt: map['created_at'] as String,
      pinHash: map['pin_hash'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id_user': idUser,
      'username': username,
      'nama': nama,
      'role': role.name,
      'created_at': createdAt,
      'pin_hash': pinHash,
    };
  }
}
