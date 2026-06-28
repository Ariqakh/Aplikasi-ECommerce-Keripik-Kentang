import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart'; // Menghubungkan ke service

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  final AuthService _authService = AuthService(); // Inisialisasi service

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  double _formOffset = 0.0;
  final double _animationDistance = -25.0;

  @override
  void initState() {
    super.initState();
    _formOffset = 0.0;
  }

  // --- LOGIC REGISTER + SIMPAN KE FIRESTORE ---
  Future<void> _registerUser() async {
    // 1. Validasi Input Dasar
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama dan Email tidak boleh kosong!")),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password tidak cocok!")),
      );
      return;
    }

    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password minimal 6 karakter!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Menggunakan AuthService untuk daftar & simpan ke Firestore
      String? result = await _authService.registerUser(
        nama: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (result == "success") {
        if (!mounted) return;

        // Animasi transisi sukses
        setState(() => _formOffset = _animationDistance);
        await Future.delayed(const Duration(milliseconds: 300));

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registrasi Berhasil! Silakan Login.")),
        );

        // Kembali ke halaman Login
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $result")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleBackToLogin() async {
    setState(() => _formOffset = _animationDistance);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF5E6),
      body: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 50),
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
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
                  spreadRadius: 2,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'REGISTER',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF422817),
                    fontFamily: 'Serif',
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Daftar sekarang untuk mulai belanja.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xFF5A3821), fontSize: 16, height: 1.4),
                ),
                const SizedBox(height: 30),
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOutCubic,
                  tween: Tween<double>(begin: 15.0, end: _formOffset),
                  builder: (context, offset, child) {
                    return Transform.translate(
                      offset: Offset(0, offset),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 400),
                        opacity: _formOffset == _animationDistance ? 0.0 : 1.0,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      _buildLabel("Nama Lengkap"),
                      const SizedBox(height: 5),
                      _buildTextField(_nameController, Icons.person_outline, "Inumaki Toge"),
                      const SizedBox(height: 15),
                      _buildLabel("Email"),
                      const SizedBox(height: 5),
                      _buildTextField(_emailController, Icons.email_outlined, "nama@email.com",
                          keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 15),
                      _buildLabel("Password"),
                      const SizedBox(height: 5),
                      _buildTextField(
                        _passwordController,
                        Icons.lock_outline,
                        "••••••••",
                        isPassword: true,
                        obscureValue: _obscurePassword,
                        onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      const SizedBox(height: 15),
                      _buildLabel("Konfirmasi Password"),
                      const SizedBox(height: 5),
                      _buildTextField(
                        _confirmPasswordController,
                        Icons.lock_reset_outlined,
                        "••••••••",
                        isPassword: true,
                        obscureValue: _obscureConfirm,
                        onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      const SizedBox(height: 35),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _registerUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFB800),
                            foregroundColor: const Color(0xFF422817),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
                            elevation: 4,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Color(0xFF422817), strokeWidth: 3),
                                )
                              : const Text("Daftar",
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Sudah punya akun? ",
                              style: TextStyle(color: Color(0xFF8B5E3C), fontSize: 16)),
                          GestureDetector(
                            onTap: _handleBackToLogin,
                            child: const Text("Login",
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
    );
  }

  Widget _buildLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF422817), fontSize: 15)),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, IconData icon, String hint,
      {bool isPassword = false,
      bool? obscureValue,
      VoidCallback? onToggle,
      TextInputType keyboardType = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4D3).withOpacity(0.6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? (obscureValue ?? true) : false,
        keyboardType: keyboardType,
        style: const TextStyle(color: Color(0xFF422817)),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                      (obscureValue ?? true) ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.grey.shade500),
                  onPressed: onToggle,
                )
              : null,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        ),
      ),
    );
  }
}