import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();

  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  Database? _database;

  /// Lokasi database khusus untuk pengujian.
  /// Pada aplikasi produksi selalu null, sehingga
  /// database tetap disimpan di direktori default
  /// perangkat (kios_one.db).
  String? _pathUntukUji;

  @visibleForTesting
  set databasePathUntukUji(String path) {
    _pathUntukUji = path;
  }

  /// Menutup database dan menghapus cache singleton.
  /// Hanya untuk pengujian.
  @visibleForTesting
  Future<void> tutupDatabaseUntukUji() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();

    final path = _pathUntukUji ?? join(databasePath, 'kios_one.db');

    return openDatabase(
      path,
      version: 7,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
      onConfigure: (db) async {
        // Aktifkan penegakan foreign key pada koneksi ini.
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id_user INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        nama TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'admin',
        pin_hash TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE kategori (
        id_kategori INTEGER PRIMARY KEY AUTOINCREMENT,
        nama_kategori TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE barang (
        id_barang INTEGER PRIMARY KEY AUTOINCREMENT,
        kode_barang TEXT NOT NULL UNIQUE,
        nama_barang TEXT NOT NULL,
        id_kategori INTEGER,
        satuan TEXT NOT NULL,
        harga_beli REAL NOT NULL DEFAULT 0,
        harga_jual REAL NOT NULL DEFAULT 0,
        stok INTEGER NOT NULL DEFAULT 0,
        stok_minimum INTEGER NOT NULL DEFAULT 5,
        foto TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (id_kategori)
          REFERENCES kategori(id_kategori)
      )
    ''');

    await db.execute('''
      CREATE TABLE stok_masuk (
        id_stok_masuk INTEGER PRIMARY KEY AUTOINCREMENT,
        id_barang INTEGER NOT NULL,
        tanggal TEXT NOT NULL,
        jumlah INTEGER NOT NULL,
        harga_beli REAL NOT NULL,
        subtotal REAL NOT NULL,
        keterangan TEXT,
        FOREIGN KEY (id_barang)
          REFERENCES barang(id_barang)
      )
    ''');

    await db.execute('''
      CREATE TABLE penjualan (
        id_penjualan INTEGER PRIMARY KEY AUTOINCREMENT,
        nomor_transaksi TEXT NOT NULL UNIQUE,
        tanggal TEXT NOT NULL,
        total REAL NOT NULL,
        bayar REAL NOT NULL,
        kembalian REAL NOT NULL,
        id_user INTEGER,
        FOREIGN KEY (id_user)
          REFERENCES users(id_user)
      )
    ''');

    await db.execute('''
      CREATE TABLE detail_penjualan (
        id_detail_penjualan INTEGER PRIMARY KEY AUTOINCREMENT,
        id_penjualan INTEGER NOT NULL,
        id_barang INTEGER NOT NULL,
        jumlah INTEGER NOT NULL,
        harga_jual REAL NOT NULL,
        harga_beli REAL NOT NULL,
        subtotal REAL NOT NULL,
        keuntungan REAL NOT NULL,
        FOREIGN KEY (id_penjualan)
          REFERENCES penjualan(id_penjualan),
        FOREIGN KEY (id_barang)
          REFERENCES barang(id_barang)
      )
    ''');

    await db.execute('''
      CREATE TABLE pemasukan (
        id_pemasukan INTEGER PRIMARY KEY AUTOINCREMENT,
        tanggal TEXT NOT NULL,
        sumber TEXT NOT NULL,
        nominal REAL NOT NULL,
        keterangan TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE pengeluaran (
        id_pengeluaran INTEGER PRIMARY KEY AUTOINCREMENT,
        tanggal TEXT NOT NULL,
        kategori TEXT NOT NULL,
        nominal REAL NOT NULL,
        keterangan TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE retur (
        id_retur INTEGER PRIMARY KEY AUTOINCREMENT,
        nomor_retur TEXT NOT NULL UNIQUE,
        id_penjualan INTEGER NOT NULL,
        tanggal TEXT NOT NULL,
        total_nilai REAL NOT NULL,
        catatan TEXT,
        FOREIGN KEY (id_penjualan)
          REFERENCES penjualan(id_penjualan)
      )
    ''');

    await db.execute('''
      CREATE TABLE detail_retur (
        id_detail_retur INTEGER PRIMARY KEY AUTOINCREMENT,
        id_retur INTEGER NOT NULL,
        id_detail_penjualan INTEGER NOT NULL,
        id_barang INTEGER NOT NULL,
        jumlah INTEGER NOT NULL,
        harga_satuan REAL NOT NULL,
        subtotal REAL NOT NULL,
        alasan TEXT NOT NULL DEFAULT '',
        kondisi TEXT NOT NULL DEFAULT 'layak',
        FOREIGN KEY (id_retur)
          REFERENCES retur(id_retur),
        FOREIGN KEY (id_barang)
          REFERENCES barang(id_barang)
      )
    ''');

    await db.execute('''
      CREATE TABLE pengaturan (
        id_pengaturan INTEGER PRIMARY KEY AUTOINCREMENT,
        nama_kios TEXT NOT NULL,
        nama_pemilik TEXT NOT NULL,
        alamat TEXT NOT NULL,
        nomor_telepon TEXT NOT NULL
      )
    ''');

    // Kategori awal.
    final categories = [
      'Sembako',
      'Minuman',
      'Makanan',
      'Kebutuhan Rumah Tangga',
      'Lainnya',
    ];

    for (final category in categories) {
      await db.insert('kategori', {'nama_kategori': category});
    }

    // Informasi awal kios.
    await db.insert('pengaturan', {
      'nama_kios': 'KIOS ONE',
      'nama_pemilik': 'Admin',
      'alamat': '',
      'nomor_telepon': '',
    });

    // Akun dibuat oleh pemilik melalui
    // penyiapan PIN awal. Tidak ada
    // kredensial bawaan yang ditanamkan.
  }

  /// Migration dari versi lama. Hanya menambah kolom,
  /// tidak pernah menghapus tabel atau data.
  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // Versi 2: menambah kolom foto pada tabel barang.
      await _pastikanKolomFoto(db);
    }

    if (oldVersion < 3) {
      // Versi 3: memastikan kolom foto tersedia.
      // Memperbaiki database versi 2 yang dibuat
      // tanpa kolom foto (misalnya dari build perantara).
      await _pastikanKolomFoto(db);
    }

    if (oldVersion < 4) {
      // Versi 4: menambah tabel retur barang.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS retur (
          id_retur INTEGER PRIMARY KEY AUTOINCREMENT,
          nomor_retur TEXT NOT NULL UNIQUE,
          id_penjualan INTEGER NOT NULL,
          tanggal TEXT NOT NULL,
          total_nilai REAL NOT NULL,
          catatan TEXT,
          FOREIGN KEY (id_penjualan)
            REFERENCES penjualan(id_penjualan)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS detail_retur (
          id_detail_retur INTEGER PRIMARY KEY AUTOINCREMENT,
          id_retur INTEGER NOT NULL,
          id_detail_penjualan INTEGER NOT NULL,
          id_barang INTEGER NOT NULL,
          jumlah INTEGER NOT NULL,
          harga_satuan REAL NOT NULL,
          subtotal REAL NOT NULL,
          alasan TEXT NOT NULL DEFAULT '',
          kondisi TEXT NOT NULL DEFAULT 'layak',
          FOREIGN KEY (id_retur)
            REFERENCES retur(id_retur),
          FOREIGN KEY (id_barang)
            REFERENCES barang(id_barang)
        )
      ''');
    }
    if (oldVersion < 6) {
      // Versi 6: kolom pin_hash untuk login PIN.
      // Tabel users dibuat lebih dulu jika belum
      // ada (database lama mungkin tidak memilikinya).
      await _pastikanTabelUsers(db);
      await _pastikanKolomPin(db);
    }

    if (oldVersion < 7) {
      // Versi 7: tabel penjualan lama mungkin belum
      // mempunyai kolom id_user, sehingga transaksi
      // kasir tidak dapat mengaitkan akun yang login.
      await _pastikanKolomIdUserPenjualan(db);
    }
  }

  /// Membuat tabel users jika belum ada.
  ///
  /// Database lama (sebelum versi 5) mungkin
  /// belum memiliki tabel ini, sehingga
  /// penambahan kolom tidak dapat dilakukan
  /// langsung.
  Future<void> _pastikanTabelUsers(Database db) async {
    final tabel = await db.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' AND name = 'users'",
    );

    if (tabel.isNotEmpty) return;

    await db.execute('''
      CREATE TABLE users (
        id_user INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        nama TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'admin',
        pin_hash TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// Menambahkan kolom foto jika belum ada.
  /// Aman dipanggil berkali-kali: memeriksa dengan
  /// PRAGMA table_info agar tidak menambah kolom dua kali.
  Future<void> _pastikanKolomFoto(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(barang)');
    final adaFoto = columns.any((column) => column['name'] == 'foto');

    if (!adaFoto) {
      await db.execute('ALTER TABLE barang ADD COLUMN foto TEXT');
    }
  }

  /// Menambahkan kolom pin_hash jika belum ada.
  /// Akun lama tanpa PIN tetap dapat masuk
  /// melalui penyiapan PIN awal.
  Future<void> _pastikanKolomPin(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(users)');
    final adaPin = columns.any((column) => column['name'] == 'pin_hash');

    if (!adaPin) {
      await db.execute('ALTER TABLE users ADD COLUMN pin_hash TEXT');
    }
  }

  /// Menambahkan kolom id_user pada tabel penjualan
  /// jika database lama dibuat sebelum kolom
  /// tersebut ada. Foreign key tidak dapat
  /// ditambahkan via ALTER TABLE, jadi migrasi ini
  /// hanya memeriksa kolom dan menjaga data lama tetap utuh.
  Future<void> _pastikanKolomIdUserPenjualan(Database db) async {
    final tabel = await db.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' AND name = 'penjualan'",
    );

    if (tabel.isEmpty) return;

    final columns = await db.rawQuery('PRAGMA table_info(penjualan)');
    final adaIdUser = columns.any((column) => column['name'] == 'id_user');

    if (!adaIdUser) {
      await db.execute('ALTER TABLE penjualan ADD COLUMN id_user INTEGER');
    }
  }
}
