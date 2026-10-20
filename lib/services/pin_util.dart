import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Jumlah iterasi PBKDF2 bawaan untuk PIN baru.
const int iterasiPinBawaan = 120000;

/// Panjang salt acak dalam byte.
const int panjangSaltPin = 16;

/// Panjang hash output dalam byte (SHA-256).
const int panjangHashPin = 32;

/// Membuat salt acak unik per akun.
String buatSaltPin() {
  final random = Random.secure();
  final bytes = List<int>.generate(
    panjangSaltPin,
    (_) => random.nextInt(256),
  );

  return _keHex(Uint8List.fromList(bytes));
}

/// Menghitung hash PBKDF2-HMAC-SHA256 dari PIN
/// dengan salt (hex) dan jumlah iterasi tertentu.
String hashPin(
  String pin,
  String saltHex, {
  int iterasi = iterasiPinBawaan,
}) {
  final salt = _dariHex(saltHex);
  final dk = _pbkdf2HmacSha256(
    password: pin,
    salt: salt,
    iterasi: iterasi,
    panjangByte: panjangHashPin,
  );

  return _keHex(dk);
}

/// Membuat string tersimpan `salt:iterasi:hash`
/// untuk PIN baru dengan salt acak unik.
String hashPinBaru(String pin, {int iterasi = iterasiPinBawaan}) {
  final salt = buatSaltPin();

  return '$salt:$iterasi:${hashPin(pin, salt, iterasi: iterasi)}';
}

/// Memverifikasi PIN terhadap string tersimpan
/// `salt:iterasi:hash`.
bool verifikasiPin(String pin, String tersimpan) {
  final bagian = tersimpan.split(':');

  if (bagian.length != 3) {
    return false;
  }

  final iterasi = int.tryParse(bagian[1]);

  if (iterasi == null || iterasi < 1) {
    return false;
  }

  final hash = hashPin(pin, bagian[0], iterasi: iterasi);

  return _samaKonstan(hash, bagian[2]);
}

/// PIN harus terdiri dari tepat 6 digit angka.
bool pinValid(String pin) {
  if (pin.length != 6) {
    return false;
  }

  for (var i = 0; i < pin.length; i++) {
    final kode = pin.codeUnitAt(i);
    if (kode < 0x30 || kode > 0x39) {
      return false;
    }
  }

  return true;
}

/// Membandingkan dua string dalam waktu konstan
/// agar tidak bocor panjang awalan yang sama.
bool _samaKonstan(String a, String b) {
  if (a.length != b.length) {
    return false;
  }

  var hasil = 0;
  for (var i = 0; i < a.length; i++) {
    hasil |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }

  return hasil == 0;
}

/// PBKDF2 (RFC 8018) dengan PRF HMAC-SHA256.
///
/// DK = T1 || T2 || ... || Tl
/// Ti = F(P, S, c, i)
/// F = U1 ^ U2 ^ ... ^ Uc, dengan
/// U1 = PRF(P, S || INT(i)) dan Un = PRF(P, U(n-1)).
Uint8List _pbkdf2HmacSha256({
  required String password,
  required Uint8List salt,
  required int iterasi,
  required int panjangByte,
}) {
  final prf = Hmac(sha256, utf8.encode(password));
  final hasil = BytesBuilder();

  var indeksBlok = 1;

  while (hasil.length < panjangByte) {
    // U1 = PRF(P, S || INT_32_BE(indeksBlok)).
    var sebelumnya = prf.convert([
      ...salt,
      (indeksBlok >> 24) & 0xff,
      (indeksBlok >> 16) & 0xff,
      (indeksBlok >> 8) & 0xff,
      indeksBlok & 0xff,
    ]).bytes;

    final blok = Uint8List.fromList(sebelumnya);

    // U2 sampai Uc.
    for (var i = 1; i < iterasi; i++) {
      sebelumnya = prf.convert(sebelumnya).bytes;

      for (var j = 0; j < blok.length; j++) {
        blok[j] ^= sebelumnya[j];
      }
    }

    hasil.add(blok);
    indeksBlok++;
  }

  return hasil.takeBytes().sublist(0, panjangByte);
}

String _keHex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List _dariHex(String hex) {
  final bytes = Uint8List(hex.length ~/ 2);

  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }

  return bytes;
}
