import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application_1/ui/splash_screen.dart';
import 'package:flutter_application_1/ui/auth/login_page.dart'; // Import halaman login kamu

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print("Firebase connected successfully");
  } catch (e) {
    print("Firebase error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Toko Keripik Kentang',
      theme: ThemeData(
        // Skema warna konsisten: Kuning/Oranye khas keripik
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB800),
          primary: const Color(0xFFFFB800),
        ),
        useMaterial3: true,
        fontFamily: 'Poppins', // Jika kamu menggunakan font kustom
      ),

      // Halaman pertama yang muncul tetap SplashScreen
      home: const SplashScreen(),

      // Mendaftarkan Rute (PENTING untuk Logout agar tidak error)
      routes: {
        '/login': (context) => const LoginPage(),
      },
    );
  }
}
