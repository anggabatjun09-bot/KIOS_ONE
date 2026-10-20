import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'database/database_helper.dart';
import 'screens/home_page.dart';
import 'screens/role_pilih_screen.dart';
import 'services/auth_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi data locale Indonesia agar DateFormat
  // dengan locale id_ID dapat digunakan sebelum
  // widget mana pun dibangun.
  await initializeDateFormatting('id_ID', null);
  Intl.defaultLocale = 'id_ID';

  // Membuat/membuka database SQLite.
  await DatabaseHelper.instance.database;

  runApp(const KiosOneApp());
}

class KiosOneApp extends StatelessWidget {
  const KiosOneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KIOS ONE',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const SplashScreen(),
    );
  }
}

// ======================================================
// SPLASH SCREEN
// ======================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _periksaSession();
  }

  Future<void> _periksaSession() async {
    // Tunggu sebentar agar splash terlihat.
    await Future.delayed(const Duration(milliseconds: 500));

    final session = AuthSession();
    final user = await session.currentUser();

    if (!mounted) return;

    // Session dipulihkan dari database.
    // Jika tidak ada session, kembali ke
    // halaman pilihan role.
    final tujuan = user != null
        ? HomePage(role: user.role, user: user)
        : const RolePilihScreen();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => tujuan),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                Icons.storefront,
                size: 60,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'KIOS ONE',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Kasir & Manajemen Persediaan'),
          ],
        ),
      ),
    );
  }
}
