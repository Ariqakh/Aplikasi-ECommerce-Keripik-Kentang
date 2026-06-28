import 'dart:async';
import 'package:flutter/material.dart';
// Sesuaikan import ini dengan struktur foldermu
import 'package:flutter_application_1/ui/auth/login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Kontrol untuk Logo
  double _logoOpacity = 0.0;
  double _logoScale = 0.2;

  // Kontrol untuk Teks
  double _textOpacity = 0.0;
  double _textOffset = 20.0;

  @override
  void initState() {
    super.initState();

    // 1. Munculkan Logo (setelah 300ms)
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _logoOpacity = 1.0;
          _logoScale = 1.0;
        });
      }
    });

    // 2. Munculkan Teks (setelah 1.2 detik, nunggu logo beres)
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _textOpacity = 1.0;
          _textOffset = 0.0;
        });
      }
    });

    // Timer pindah ke halaman LOGIN (setelah 5 detik)
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF0E1),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- ANIMASI LOGO ---
            AnimatedOpacity(
              duration: const Duration(milliseconds: 1000),
              opacity: _logoOpacity,
              curve: Curves.easeOut,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 1200),
                scale: _logoScale,
                curve: Curves.elasticOut,
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 200,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.fastfood,
                      size: 100,
                      color: Color(0xFF8B5E3C),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 30),

            // --- ANIMASI TEKS (FADE & SLIDE UP) ---
            AnimatedObject(
              opacity: _textOpacity,
              offset: _textOffset,
              child: Column(
                children: [
                  const Text(
                    'Keripik Kentang',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5A3821),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Text(
                    'Aneka Rasa',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF8B5E3C),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5D5C6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Renyah di setiap gigitan',
                      style: TextStyle(
                        color: Color(0xFF8B5E3C),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 50),

            // Indikator Loading
            AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: _textOpacity,
              child: const Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 4,
                        backgroundColor: Color(0xFF8B5E3C),
                      ),
                      SizedBox(width: 8),
                      CircleAvatar(radius: 3, backgroundColor: Colors.grey),
                      SizedBox(width: 8),
                      CircleAvatar(radius: 3, backgroundColor: Colors.grey),
                    ],
                  ),
                  SizedBox(height: 30),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF8B5E3C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget untuk animasi slide up
class AnimatedObject extends StatelessWidget {
  final double opacity;
  final double offset;
  final Widget child;

  const AnimatedObject({
    super.key,
    required this.opacity,
    required this.offset,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 1000),
      opacity: opacity,
      curve: Curves.easeIn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, offset, 0),
        child: child,
      ),
    );
  }
}
