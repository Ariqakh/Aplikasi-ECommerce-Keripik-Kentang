import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

// Import halaman navigasi
import 'home_page.dart';
import 'transaction_history.dart';
import 'cart_page.dart';
import '../auth/login_page.dart';
import '../../models/user_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedIndex = 2;
  final Color bgCream = const Color(0xFFFDF5E6);
  final Color darkBrown = const Color(0xFF422817);
  final Color primaryYellow = const Color(0xFFFFB800);
  final Color textGrey = const Color(0xFF8E8E8E);

  final User? currentUser = FirebaseAuth.instance.currentUser;

  bool _isObscureOld = true;
  bool _isObscureNew = true;

  // --- FUNGSI KIRIM KENDALA ---
  Future<void> _kirimKendala(
      String nama, String nomorHp, String keluhan) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'ariqajinan@gmail.com',
      queryParameters: {
        'subject': 'Bantuan Aplikasi - $nama',
        'body': 'Nama: $nama\nNomor HP: $nomorHp\n\nKendala:\n$keluhan',
      },
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka aplikasi email.')),
      );
    }
  }

  void _tampilkanFormBantuan() {
    final TextEditingController namaCtrl = TextEditingController();
    final TextEditingController hpCtrl = TextEditingController();
    final TextEditingController keluhanCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Pusat Bantuan"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: namaCtrl,
                  decoration: const InputDecoration(labelText: "Nama Lengkap")),
              TextField(
                  controller: hpCtrl,
                  decoration: const InputDecoration(labelText: "Nomor HP")),
              TextField(
                  controller: keluhanCtrl,
                  decoration: const InputDecoration(
                      labelText: "Tulis kendala Anda...", hintMaxLines: 3),
                  maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal")),
          ElevatedButton(
            onPressed: () {
              if (namaCtrl.text.isNotEmpty && keluhanCtrl.text.isNotEmpty) {
                Navigator.pop(context);
                _kirimKendala(namaCtrl.text, hpCtrl.text, keluhanCtrl.text);
              }
            },
            child: const Text("Kirim Email"),
          ),
        ],
      ),
    );
  }

  // --- FUNGSI EDIT NAMA (DIPERBAIKI) ---
  void _showEditNameDialog(String currentName) {
    TextEditingController nameController =
        TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Ubah Nama"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: "Nama Lengkap"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Batal", style: TextStyle(color: textGrey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryYellow),
            onPressed: () async {
              String newName = nameController.text.trim();
              if (newName.isNotEmpty && currentUser != null) {
                // Update ke Firestore
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser!.uid)
                    .update({'nama': newName}); // Field 'nama' sesuai database

                if (mounted) {
                  setState(() {}); // Update UI lokal
                  Navigator.pop(context);
                }
              }
            },
            child: const Text("Simpan", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // --- FUNGSI GANTI PASSWORD ---
  void _showChangePasswordDialog() {
    TextEditingController oldPassController = TextEditingController();
    TextEditingController newPassController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          title: Text("Keamanan Akun",
              style: TextStyle(color: darkBrown, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Masukkan sandi lama dan baru Anda."),
              const SizedBox(height: 15),
              TextField(
                controller: oldPassController,
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
                controller: newPassController,
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
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (newPassController.text.length < 6) {
                  _showSnippet("Sandi baru minimal 6 karakter!");
                  return;
                }
                try {
                  AuthCredential credential = EmailAuthProvider.credential(
                    email: currentUser!.email!,
                    password: oldPassController.text,
                  );
                  await currentUser!.reauthenticateWithCredential(credential);
                  await currentUser!.updatePassword(newPassController.text);

                  if (!mounted) return;
                  Navigator.pop(context);
                  _showSnippet("Password berhasil diubah!");
                } catch (e) {
                  _showSnippet(
                      "Gagal: Sandi lama salah atau kendala jaringan.");
                }
              },
              child: Text("Update",
                  style:
                      TextStyle(color: darkBrown, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnippet(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgCream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset('assets/images/logo.png',
                height: 25,
                errorBuilder: (c, o, s) =>
                    Icon(Icons.fastfood, color: primaryYellow)),
            const SizedBox(width: 8),
            Text("Keripik Kentang\nAneka Rasa",
                style: TextStyle(
                    color: darkBrown,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => const CartPage())),
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.data!.exists)
            return const Center(child: Text("Data pengguna tidak ditemukan."));

          var userData =
              UserModel.fromMap(snapshot.data!.data() as Map<String, dynamic>);

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: primaryYellow, width: 3)),
                        child: const CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          backgroundImage:
                              AssetImage('assets/images/avatar.png'),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(userData.nama,
                              style: TextStyle(
                                  color: darkBrown,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          IconButton(
                            onPressed: () => _showEditNameDialog(userData.nama),
                            icon: Icon(Icons.edit,
                                size: 18, color: darkBrown.withOpacity(0.5)),
                          )
                        ],
                      ),
                      Text(userData.email,
                          style: TextStyle(
                              color: darkBrown.withOpacity(0.7), fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryYellow,
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 20),
                    ),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const TransactionHistoryPage())),
                    child: Row(
                      children: const [
                        Icon(Icons.assignment_outlined, color: Colors.black),
                        SizedBox(width: 15),
                        Expanded(
                            child: Text("Riwayat Pesanan",
                                style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16))),
                        Icon(Icons.chevron_right, color: Colors.black),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.help_outline,
                            color: Color(0xFF422817)),
                        title: const Text("Pusat Bantuan"),
                        onTap: _tampilkanFormBantuan,
                      ),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      _buildMenuItem(
                          Icons.lock_reset_rounded, "Ganti Kata Sandi",
                          onTap: _showChangePasswordDialog),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      _buildMenuItem(Icons.logout_rounded, "Keluar",
                          isLogout: true, onTap: () async {
                        await FirebaseAuth.instance.signOut();
                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const LoginPage()),
                              (route) => false);
                        }
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildMenuItem(IconData icon, String title,
      {bool isLogout = false, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Icon(icon, color: isLogout ? Colors.red : Colors.grey[700]),
      title: Text(title,
          style: TextStyle(
              color: isLogout ? Colors.red : Colors.black,
              fontWeight: FontWeight.w500)),
      trailing: isLogout ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(35), topRight: Radius.circular(35)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_outlined, "Beranda", 0),
          _navItem(Icons.receipt_long, "Riwayat Pesanan", 1),
          _navItem(Icons.person_outline, "Akun", 2),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool active = index == _selectedIndex;
    return InkWell(
      onTap: () {
        if (index == _selectedIndex) return;
        if (index == 0)
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const HomePage()));
        else if (index == 1)
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const TransactionHistoryPage()));
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFFFE082) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: darkBrown),
          ),
          const SizedBox(height: 4),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
