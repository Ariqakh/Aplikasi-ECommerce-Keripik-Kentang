import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import 'register_page.dart';
import '../user/home_page.dart';
import '../admin/dashboard_admin.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _obscureText = true;
  bool _isLoading = false;

  double _formOffset = 0.0;
  final double _animationDistance = -25.0;

  @override
  void initState() {
    super.initState();
    _formOffset = 0.0;
  }

  // --- LOGIKA LUPA PASSWORD ---
  Future<void> _handleForgotPassword() async {
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      _showSnippet("Masukkan email yang valid untuk reset password!");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      _showSnippet("Link reset telah dikirim ke email!", isSuccess: true);
    } on FirebaseAuthException catch (e) {
      _showSnippet(e.code == 'user-not-found'
          ? "Email tidak terdaftar."
          : "Gagal mengirim link.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIKA LOGIN MANUAL ---
  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnippet("Email dan Password harus diisi!");
      return;
    }

    setState(() => _isLoading = true);
    try {
      UserModel? user = await _authService.loginUser(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null) {
        if (!mounted) return;
        if (user.role == 'admin') {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const DashboardAdminPage()));
        } else {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const HomePage()));
        }
      } else {
        _showSnippet("Login Gagal: Data user tidak ditemukan.");
      }
    } catch (e) {
      _showSnippet("Terjadi Kesalahan: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIKA GOOGLE SIGN IN (PERBAIKAN: ALWAYS PICK ACCOUNT) ---
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // PAKSA KELUAR DULU agar setiap klik tombol 'Google' selalu muncul pilihan akun
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user != null) {
        // Simpan/Update data ke Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'nama': userCredential.user!.displayName ?? "User Google",
          'email': userCredential.user!.email,
          'role': 'pembeli', // Default role untuk Google Sign-In
          'uid': userCredential.user!.uid,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const HomePage()));
      }
    } catch (e) {
      _showSnippet("Login Google Gagal: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnippet(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: isSuccess ? Colors.green : Colors.redAccent),
    );
  }

  void _handleGoToRegister() async {
    setState(() => _formOffset = _animationDistance);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RegisterPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    if (mounted) setState(() => _formOffset = 0.0);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF5E6),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 70),
                padding:
                    const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [Colors.white, Color(0xFFFFF7E9)],
                  ),
                  borderRadius: BorderRadius.circular(60),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 30,
                        spreadRadius: 2)
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('LOGIN',
                        style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF422817),
                            fontFamily: 'Serif')),
                    const SizedBox(height: 15),
                    const Text(
                        'Nikmati kerenyahan camilan\nfavoritmu sekarang.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color(0xFF5A3821),
                            fontSize: 16,
                            height: 1.4)),
                    const SizedBox(height: 40),
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(begin: 15.0, end: _formOffset),
                      builder: (context, offset, child) {
                        return Transform.translate(
                          offset: Offset(0, offset),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 400),
                            opacity:
                                _formOffset == _animationDistance ? 0.0 : 1.0,
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          _buildLabel("Email"),
                          const SizedBox(height: 8),
                          _buildTextField(_emailController,
                              Icons.email_outlined, "nama@email.com"),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildLabel("Password"),
                              GestureDetector(
                                onTap: _handleForgotPassword,
                                child: const Text("Lupa?",
                                    style: TextStyle(
                                        color: Color(0xFFFFB800),
                                        fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildTextField(_passwordController,
                              Icons.lock_outline, "••••••••",
                              isPassword: true),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            height: 65,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFB800),
                                foregroundColor: const Color(0xFF422817),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(35)),
                                elevation: 4,
                              ),
                              child: const Text("Masuk",
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 30),
                          const Row(
                            children: [
                              Expanded(
                                  child: Divider(
                                      color: Colors.black12,
                                      indent: 10,
                                      endIndent: 10)),
                              Text("atau",
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 14)),
                              Expanded(
                                  child: Divider(
                                      color: Colors.black12,
                                      indent: 10,
                                      endIndent: 10)),
                            ],
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: OutlinedButton(
                              onPressed:
                                  _isLoading ? null : _handleGoogleSignIn,
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    const Color.fromARGB(255, 253, 243, 227),
                                side:
                                    const BorderSide(color: Color(0xFFEEEEEE)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(35)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset('assets/images/google.png',
                                      width: 24,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.g_mobiledata,
                                                  size: 30)),
                                  const SizedBox(width: 12),
                                  const Text("Google",
                                      style: TextStyle(
                                          color: Color(0xFF422817),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Belum punya akun? ",
                                  style: TextStyle(
                                      color: Color(0xFF8B5E3C), fontSize: 16)),
                              GestureDetector(
                                onTap: _handleGoToRegister,
                                child: const Text("Daftar",
                                    style: TextStyle(
                                        color: Color(0xFFFFB800),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFB800))),
            ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF422817),
                fontSize: 15)),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, IconData icon, String hint,
      {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF1F4D3).withOpacity(0.6),
          borderRadius: BorderRadius.circular(30)),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscureText : false,
        style: const TextStyle(color: Color(0xFF422817)),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                      _obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.grey.shade500),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                )
              : null,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        ),
      ),
    );
  }
}
