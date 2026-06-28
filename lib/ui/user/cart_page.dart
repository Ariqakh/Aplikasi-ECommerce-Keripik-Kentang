import 'dart:convert'; // Kunci utama untuk mendecode gambar teks Base64 produk dari Firestore
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Digunakan untuk melakukan formatting nominal mata uang

// Import halaman tujuan
import 'checkout_page.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'transaction_history.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Palet Warna sesuai desain
  final Color primaryYellow = const Color(0xFFFFB800);
  final Color bgLight = const Color(0xFFFDF5E6);
  final Color darkBrown = const Color(0xFF422817);

  // Perbaikan format nominal menggunakan format titik (.) sebagai pemisah ribuan rupiah
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // Fungsi Update Jumlah Item
  Future<void> _updateQuantity(
      String docId, int newQuantity, int pricePerItem) async {
    if (newQuantity < 1) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser?.uid)
        .collection('cart')
        .doc(docId)
        .update({
      'jumlah': newQuantity,
    });
  }

  // Fungsi Hapus Item
  Future<void> _deleteItem(String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser?.uid)
        .collection('cart')
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: innerBoxIsScrolled ? 2 : 0,
              pinned: true,
              floating: true,
              centerTitle: false,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: darkBrown),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                "Keranjang Belanja",
                style: TextStyle(
                  color: darkBrown,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.transparent,
                    radius: 18,
                    child: Image.asset('assets/images/logo.png', height: 30,
                        errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.fastfood,
                          color: primaryYellow, size: 24);
                    }),
                  ),
                )
              ],
            ),
          ];
        },
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser?.uid)
              .collection('cart')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF422817)));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart_outlined,
                        size: 80, color: darkBrown.withOpacity(0.2)),
                    const SizedBox(height: 10),
                    Text("Belum ada pesanan",
                        style: TextStyle(
                            color: darkBrown,
                            fontSize: 18,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            }

            final cartDocs = snapshot.data!.docs;

            int subtotal = 0;
            for (var doc in cartDocs) {
              final data = doc.data() as Map<String, dynamic>;
              final int hargaSatuan = data['hargaSatuan'] ?? 0;
              final int jumlah = data['jumlah'] ?? 0;
              subtotal += (hargaSatuan * jumlah);
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Pesanan Kamu",
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: darkBrown,
                          height: 1.5)),
                  const SizedBox(height: 10),
                  Text("Nikmati keripik kentang premium buatan rumah kami.",
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cartDocs.length,
                    itemBuilder: (context, index) {
                      final doc = cartDocs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final String id = doc.id;
                      final String namaProduk = data['namaProduk'] ?? '';
                      final String rasa = data['rasa'] ?? '';
                      final String ukuran = data['ukuran'] ?? '';
                      final int hargaSatuan = data['hargaSatuan'] ?? 0;
                      final int jumlah = data['jumlah'] ?? 0;
                      final int totalHargaItem = hargaSatuan * jumlah;
                      final String imageBase64 = data['image_url'] ??
                          ''; // Menyelaraskan field key image dinamis

                      return _buildCartItem(
                        id: id,
                        namaProduk: namaProduk,
                        rasa: rasa,
                        ukuran: ukuran,
                        jumlah: jumlah,
                        totalHargaItem: totalHargaItem,
                        unitPrice: hargaSatuan,
                        imageString: imageBase64,
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFE6D5).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Ringkasan Pesanan",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                        const SizedBox(height: 20),
                        _buildSummaryRow("Harga (${cartDocs.length} Produk)",
                            _currencyFormat.format(subtotal)),
                        const Divider(height: 30, thickness: 1),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Subtotal Produk",
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w500)),
                            Text(_currencyFormat.format(subtotal),
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: darkBrown)),
                          ],
                        ),
                        const SizedBox(height: 25),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const CheckoutPage()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryYellow,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("Checkout Sekarang",
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                SizedBox(width: 10),
                                Icon(Icons.arrow_forward, color: Colors.black),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildCartItem({
    required String id,
    required String namaProduk,
    required String rasa,
    required String ukuran,
    required int jumlah,
    required int totalHargaItem,
    required int unitPrice,
    required String imageString,
  }) {
    // Alur decoder gambar Base64 Data URI aman tanpa memory leaks
    Widget itemImageWidget;
    try {
      if (imageString.startsWith("data:image")) {
        final base64String = imageString.split(',').last;
        itemImageWidget = Image.memory(
          base64Decode(base64String),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } else {
        itemImageWidget = Icon(Icons.fastfood, color: darkBrown, size: 40);
      }
    } catch (e) {
      itemImageWidget = Icon(Icons.broken_image, color: darkBrown, size: 35);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFFE8E4D9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: itemImageWidget, // Merender foto produk nyata Base64
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        namaProduk,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 22),
                      onPressed: () => _deleteItem(id),
                      visualDensity: VisualDensity.compact,
                    )
                  ],
                ),
                Text(
                  rasa,
                  style: TextStyle(
                      color: darkBrown,
                      fontWeight: FontWeight.w800,
                      fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  "Ukuran: $ukuran",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _currencyFormat.format(
                          totalHargaItem), // Menampilkan format nominal bertitik (.)
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: darkBrown,
                          fontSize: 17),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          _qtyBtn(Icons.remove,
                              () => _updateQuantity(id, jumlah - 1, unitPrice)),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Text("$jumlah",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          _qtyBtn(Icons.add,
                              () => _updateQuantity(id, jumlah + 1, unitPrice)),
                        ],
                      ),
                    )
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Icon(icon, size: 18, color: darkBrown),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- BOTTOM NAV BAR ---
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
          _buildBottomNavItem(Icons.home_outlined, "Beranda", 0),
          _buildBottomNavItem(
              Icons.receipt_long_outlined, "Riwayat Pesanan", 1),
          _buildBottomNavItem(Icons.person_outline, "Akun", 2),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, int index) {
    bool active = index == 0;
    return InkWell(
      onTap: () {
        if (index == 0) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const HomePage()));
        } else if (index == 1) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const TransactionHistoryPage()));
        } else if (index == 2) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const ProfilePage()));
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFFFE082) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: darkBrown),
          ),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
