import 'package:intl/intl.dart';

/// Memformat angka menjadi Rupiah, contoh: Rp12.500
String formatRupiah(num angka) {
  final format = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  return format.format(angka);
}

/// Memformat string tanggal ISO menjadi `dd MMM yyyy`.
String formatTanggal(String iso) {
  final tanggal = DateTime.tryParse(iso);

  if (tanggal == null) return iso;

  return DateFormat('dd MMM yyyy', 'id_ID').format(tanggal);
}

/// Memformat string tanggal ISO menjadi
/// `dd MMM yyyy HH:mm`.
String formatDateTime(String iso) {
  final tanggal = DateTime.tryParse(iso);

  if (tanggal == null) return iso;

  return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(tanggal);
}

/// Tanggal hari ini dalam format `yyyy-MM-dd`.
String tanggalHariIni() {
  final now = DateTime.now();

  return '${now.year.toString().padLeft(4, '0')}'
      '-${now.month.toString().padLeft(2, '0')}'
      '-${now.day.toString().padLeft(2, '0')}';
}
