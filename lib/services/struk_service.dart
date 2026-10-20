import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../database/database_helper.dart';
import '../models/pengaturan.dart';
import '../models/struk.dart';
import '../utils/kios_utils.dart';

/// Lebar kertas thermal 58 mm dalam poin
/// (1 mm = 72 / 25.4 poin).
const lebarKertasStruk = 58.0 * 72 / 25.4;

/// Tinggi dasar struk sebelum isi barang
/// (judul, info transaksi, pembayaran,
/// dan ucapan).
const tinggiDasarStruk = 190.0;

/// Perkiraan tinggi satu baris struk.
const tinggiPerBarisStruk = 15.0;

/// Tinggi halaman maksimum. Daftar barang
/// panjang yang melewati batas ini tetap
/// ditampilkan pada halaman berikutnya
/// (MultiPage), tidak terpotong.
const tinggiMaksimumHalaman = 2000.0;

/// Layanan struk PDF.
///
/// Seluruh operasi hanya membaca data
/// dari SQLite. Membuat atau menampilkan
/// struk tidak pernah membuat transaksi
/// baru, mengurangi stok, mengubah
/// pembayaran, atau mengubah laporan.
class StrukService {
  /// Mengambil data struk dari transaksi
  /// yang sudah tersimpan.
  ///
  /// Mengembalikan null jika transaksi
  /// tidak ditemukan.
  Future<StrukData?> siapkanStruk(int idPenjualan) async {
    final db = await DatabaseHelper.instance.database;

    // Transaksi penjualan asli.
    final penjualanRows = await db.query(
      'penjualan',
      where: 'id_penjualan = ?',
      whereArgs: [idPenjualan],
    );

    if (penjualanRows.isEmpty) return null;

    final penjualan = penjualanRows.first;

    // Item barang beserta nama barang.
    final detailRows = await db.rawQuery(
      '''
      SELECT barang.nama_barang AS nama_barang,
             detail_penjualan.jumlah AS jumlah,
             detail_penjualan.harga_jual AS harga_jual,
             detail_penjualan.subtotal AS subtotal
      FROM detail_penjualan
      JOIN barang ON barang.id_barang = detail_penjualan.id_barang
      WHERE detail_penjualan.id_penjualan = ?
      ORDER BY detail_penjualan.id_detail_penjualan ASC
      ''',
      [idPenjualan],
    );

    // Informasi toko, jika ada.
    final pengaturanRows = await db.query('pengaturan', limit: 1);
    final Pengaturan? pengaturan = pengaturanRows.isEmpty
        ? null
        : Pengaturan.fromMap(pengaturanRows.first);

    // Nama kasir, jika transaksi mencatat
    // pengguna dan akun tersebut ditemukan.
    String? namaKasir;
    final idUser = penjualan['id_user'] as int?;

    if (idUser != null) {
      final userRows = await db.query(
        'users',
        columns: ['nama'],
        where: 'id_user = ?',
        whereArgs: [idUser],
      );

      if (userRows.isNotEmpty) {
        namaKasir = userRows.first['nama'] as String?;
      }
    }

    final items = [
      for (final row in detailRows)
        ItemStruk(
          namaBarang: (row['nama_barang'] as String?) ?? '',
          jumlah: (row['jumlah'] as num).toInt(),
          hargaSatuan: (row['harga_jual'] as num).toDouble(),
          subtotal: (row['subtotal'] as num).toDouble(),
        ),
    ];

    return StrukData(
      namaToko: pengaturan?.namaKios,
      alamat: pengaturan?.alamat ?? '',
      telepon: pengaturan?.nomorTelepon ?? '',
      nomorTransaksi: penjualan['nomor_transaksi'] as String,
      tanggal: penjualan['tanggal'] as String,
      namaKasir: namaKasir,
      items: items,
      // Nilai langsung dari database agar
      // tidak bertentangan dengan data
      // transaksi yang tersimpan.
      total: (penjualan['total'] as num).toDouble(),
      bayar: (penjualan['bayar'] as num).toDouble(),
      kembalian: (penjualan['kembalian'] as num).toDouble(),
    );
  }

  /// Menyusun baris-baris teks struk.
  ///
  /// Hanya memuat informasi yang tersedia;
  /// data tidak dikarang dan total tidak
  /// dihitung ulang.
  List<StrukBaris> strukBaris(StrukData data) {
    final baris = <StrukBaris>[];

    // Identitas toko.
    final namaToko = data.namaToko?.trim() ?? '';

    if (namaToko.isNotEmpty) {
      baris.add(StrukBaris(
        kiri: namaToko,
        gaya: GayaStruk.judul,
      ));
    }

    final alamat = data.alamat.trim();

    if (alamat.isNotEmpty) {
      baris.add(StrukBaris(
        kiri: alamat,
        gaya: GayaStruk.subjudul,
      ));
    }

    final telepon = data.telepon.trim();

    if (telepon.isNotEmpty) {
      baris.add(StrukBaris(
        kiri: 'Telp: $telepon',
        gaya: GayaStruk.subjudul,
      ));
    }

    baris.add(const StrukBaris(gaya: GayaStruk.garis));

    // Informasi transaksi.
    baris.add(StrukBaris(
      kiri: 'No: ${data.nomorTransaksi}',
      gaya: GayaStruk.teks,
    ));

    baris.add(StrukBaris(
      kiri: 'Tanggal: ${formatDateTime(data.tanggal)}',
      gaya: GayaStruk.teks,
    ));

    final namaKasir = data.namaKasir?.trim() ?? '';

    if (namaKasir.isNotEmpty) {
      baris.add(StrukBaris(
        kiri: 'Kasir: $namaKasir',
        gaya: GayaStruk.teks,
      ));
    }

    baris.add(const StrukBaris(gaya: GayaStruk.garis));

    // Item barang.
    for (final item in data.items) {
      final nama = item.namaBarang.trim();

      baris.add(StrukBaris(
        kiri: nama.isEmpty ? 'Barang' : nama,
        gaya: GayaStruk.teks,
      ));

      baris.add(StrukBaris(
        kiri: '  ${item.jumlah} x ${formatRupiah(item.hargaSatuan)}',
        kanan: formatRupiah(item.subtotal),
        gaya: GayaStruk.teks,
      ));
    }

    baris.add(const StrukBaris(gaya: GayaStruk.garis));

    // Pembayaran.
    baris.add(StrukBaris(
      kiri: 'TOTAL',
      kanan: formatRupiah(data.total),
      gaya: GayaStruk.tebal,
    ));

    baris.add(StrukBaris(
      kiri: 'Bayar',
      kanan: formatRupiah(data.bayar),
      gaya: GayaStruk.teks,
    ));

    baris.add(StrukBaris(
      kiri: 'Kembalian',
      kanan: formatRupiah(data.kembalian),
      gaya: GayaStruk.teks,
    ));

    baris.add(const StrukBaris(gaya: GayaStruk.spasi));

    baris.add(StrukBaris(
      kiri: 'Terima kasih',
      gaya: GayaStruk.subjudul,
    ));

    return baris;
  }

  /// Membuat dokumen PDF struk dengan lebar
  /// kertas thermal 58 mm.
  ///
  /// Tinggi halaman mengikuti jumlah baris
  /// agar daftar barang panjang tidak
  /// terpotong; bila tetap melebihi,
  /// MultiPage melanjutkan ke halaman
  /// berikutnya.
  Future<Uint8List> strukPdf(StrukData data) async {
    final baris = strukBaris(data);

    final tinggiHalaman = math.min(
      tinggiMaksimumHalaman,
      tinggiDasarStruk + baris.length * tinggiPerBarisStruk,
    );

    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat(
            lebarKertasStruk,
            tinggiHalaman,
          ),
          margin: const pw.EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 8,
          ),
        ),
        build: (context) => _bangunWidget(baris),
      ),
    );

    return document.save();
  }

  List<pw.Widget> _bangunWidget(List<StrukBaris> baris) {
    return [
      for (final baris in baris)
        switch (baris.gaya) {
          GayaStruk.judul => pw.Center(
              child: pw.Text(
                baris.kiri,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          GayaStruk.subjudul => pw.Center(
              child: pw.Text(
                baris.kiri,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 7.5),
              ),
            ),
          GayaStruk.garis => pw.Divider(
              height: 7,
              thickness: 0.6,
            ),
          GayaStruk.spasi => pw.SizedBox(height: 6),
          GayaStruk.tebal => _barisNilai(
              baris,
              gaya: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          GayaStruk.teks => _barisNilai(
              baris,
              gaya: const pw.TextStyle(fontSize: 8),
            ),
        },
    ];
  }

  pw.Widget _barisNilai(
    StrukBaris baris, {
    required pw.TextStyle gaya,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Text(baris.kiri, style: gaya),
        ),
        if (baris.kanan.isNotEmpty)
          pw.Text(baris.kanan, style: gaya),
      ],
    );
  }
}
