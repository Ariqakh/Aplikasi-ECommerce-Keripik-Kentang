import 'dart:convert'; // Enkripsi gambar ke Base64 string murni
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import alur navigasi panel admin Anda
import 'dashboard_admin.dart';
import 'manage_product.dart';
import 'order_list.dart';
import '../auth/login_page.dart'; // Sesuaikan lokasi root halaman login Anda

class ProfileAdminPage extends StatefulWidget {
  const ProfileAdminPage({super.key});

  @override
  State<ProfileAdminPage> createState() => _ProfileAdminPageState();
}

class _ProfileAdminPageState extends State<ProfileAdminPage> {
  final Color primaryYellow = const Color(0xFFFFB800);
  final Color bgLight = const Color(0xFFFDF5E6);
  final Color darkBrown = const Color(0xFF422817);
  final Color textGrey = const Color(0xFF8E8E8E);

  final User? currentUser = FirebaseAuth.instance.currentUser;

  bool _isObscureOld = true;
  bool _isObscureNew = true;

  // Indeks navigasi aktif untuk menu Akun/Profil Admin
  final int _currentIndex = 3;

  // Variabel penampung state form utama di luar builder dialog (Kunci utama anti-crash)
  File? _selectedQrFile;
  bool _isGlobalLoading = false;

  final TextEditingController _providerController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _ownerController = TextEditingController();

  @override
  void dispose() {
    _providerController.dispose();
    _numberController.dispose();
    _ownerController.dispose();
    super.dispose();
  }

  void _showChangePasswordDialog() {
    TextEditingController oldPasswordController = TextEditingController();
    TextEditingController newPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          title: Text("Keamanan Akun",
              style: TextStyle(color: darkBrown, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  "Sandi lama diperlukan untuk memverifikasi identitas Anda."),
              const SizedBox(height: 15),
              TextField(
                controller: oldPasswordController,
                obscureText: _isObscureOld,
                decoration: InputDecoration(
                  hintText: "Sandi Lama",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _isObscureOld ? Icons.visibility_off : Icons.visibility,
                        size: 20),
                    onPressed: () =>
                        setStateDialog(() => _isObscureOld = !_isObscureOld),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newPasswordController,
                obscureText: _isObscureNew,
                decoration: InputDecoration(
                  hintText: "Sandi Baru (Min. 6 Karakter)",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _isObscureNew ? Icons.visibility_off : Icons.visibility,
                        size: 20),
                    onPressed: () =>
                        setStateDialog(() => _isObscureNew = !_isObscureNew),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Batal", style: TextStyle(color: textGrey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: primaryYellow,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0),
              onPressed: () async {
                if (newPasswordController.text.length < 6) {
                  _showSnippet("Sandi baru minimal 6 karakter!");
                  return;
                }

                try {
                  AuthCredential credential = EmailAuthProvider.credential(
                      email: currentUser!.email!,
                      password: oldPasswordController.text);

                  await currentUser!.reauthenticateWithCredential(credential);
                  await currentUser!.updatePassword(newPasswordController.text);

                  Navigator.pop(context);
                  _showSnippet("Password berhasil diubah!");
                } catch (e) {
                  _showSnippet(
                      "Gagal: Sandi lama salah atau terjadi kesalahan jaringan.");
                }
              },
              child: Text("Update",
                  style:
                      TextStyle(color: darkBrown, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }),
    );
  }

  void _showSnippet(String msg) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: Stack(
        children: [
          Column(
            children: [
              // --- TOP BAR ---
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2)),
                  ],
                ),
                padding: const EdgeInsets.only(
                    left: 20, right: 20, top: 50, bottom: 7),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.account_circle_outlined,
                          color: darkBrown, size: 30),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "AKUN ADMIN",
                      style: TextStyle(
                          color: darkBrown,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  ],
                ),
              ),

              // --- CONTENT MAIN PANEL ---
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser?.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF422817)));
                    }

                    var userData = snapshot.data;
                    String nama = userData?['nama'] ?? "Admin Name";
                    String email = userData?['email'] ?? "admin@email.com";

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: primaryYellow, width: 3),
                              ),
                              child: const CircleAvatar(
                                radius: 65,
                                backgroundColor: Colors.white,
                                backgroundImage:
                                    AssetImage('assets/images/logo.png'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(nama,
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: darkBrown)),
                          Text(email,
                              style: TextStyle(fontSize: 16, color: textGrey)),
                          const SizedBox(height: 40),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 25),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(color: Colors.black12, blurRadius: 10)
                              ],
                            ),
                            child: Column(
                              children: [
                                const Divider(
                                    height: 1, indent: 20, endIndent: 20),
                                _buildMenuItem(
                                  Icons.lock_reset_rounded,
                                  "Ganti Kata Sandi",
                                  onTap: _showChangePasswordDialog,
                                ),
                                const Divider(
                                    height: 1, indent: 20, endIndent: 20),
                                _buildMenuItem(
                                  Icons.logout_rounded,
                                  "Keluar",
                                  isLogout: true,
                                  onTap: () async {
                                    await FirebaseAuth.instance.signOut();
                                    if (mounted) {
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const LoginPage()),
                                        (route) => false,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // Layer pelindung loading transparan tingkat atas
          if (_isGlobalLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF422817))),
            )
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildMenuItem(IconData icon, String title,
      {bool isLogout = false, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isLogout
              ? Colors.redAccent.withOpacity(0.1)
              : darkBrown.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            color: isLogout ? Colors.redAccent : darkBrown, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isLogout ? Colors.redAccent : darkBrown,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      trailing: isLogout
          ? null
          : Icon(Icons.arrow_forward_ios_rounded, color: textGrey, size: 16),
      onTap: onTap,
    );
  }

  // --- FOOTER SINKRON DENGAN INTEGRASI DOT BULAT INDIKATOR AKTIF ---
  Widget _buildBottomNav() {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(40), topRight: Radius.circular(40)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.analytics_outlined, "ANALISIS", 0),
          _navItem(Icons.inventory_2_outlined, "PRODUK", 1),
          _navItem(Icons.receipt_long_outlined, "PESANAN", 2),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool active = _currentIndex == index;
    return InkWell(
      onTap: () {
        if (index == 0) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const DashboardAdminPage()));
        } else if (index == 1) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const ManageProductPage()));
        } else if (index == 2) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const OrderListPage()));
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? darkBrown : textGrey, size: 28),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: active ? darkBrown : textGrey)),
          if (active)
            Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration:
                    BoxDecoration(color: darkBrown, shape: BoxShape.circle))
        ],
      ),
    );
  }
}
