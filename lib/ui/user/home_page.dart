import 'dart:convert'; // Untuk men-decode teks Base64 gambar dari Firestore
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_page.dart';
import 'detail_product_page.dart';
import 'transaction_history.dart';
import 'profile_page.dart';
import '../../models/product_model.dart'; // Import struktur ProductModel Anda

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String selectedCategory = "Semua";
  int _selectedIndex = 0;

  void _onNavTap(int index) {
    if (index == _selectedIndex) return;
    if (index == 0) {
      setState(() => _selectedIndex = index);
    } else if (index == 1) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const TransactionHistoryPage()));
    } else if (index == 2) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const ProfilePage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF5E6),
      body: Column(
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
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding:
                const EdgeInsets.only(left: 20, right: 20, top: 50, bottom: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFFDF5E6),
                      radius: 25,
                      child: Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: Image.asset('assets/images/logo.png',
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.fastfood,
                                    color: Color(0xFF422817))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // AKUN USER MENGGUNAKAN FIREBASE
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(currentUser?.uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            String name = "User";
                            if (snapshot.hasData && snapshot.data!.exists) {
                              name = snapshot.data!.get('nama') ?? "User";
                            }
                            return Text(
                              "Halo, $name",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF422817),
                                  fontSize: 16),
                            );
                          },
                        ),
                        const Text("Mau nyemil apa hari ini?",
                            style: TextStyle(
                                color: Color(0xFF422817), fontSize: 13)),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const CartPage())),
                  child: Stack(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.shopping_cart_outlined,
                            size: 28, color: Color(0xFF422817)),
                      ),
                      // Badge keranjang dihitung secara real-time dari sub-koleksi cart user
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUser?.uid)
                            .collection('cart')
                            .snapshots(),
                        builder: (context, snapshot) {
                          int totalItems = 0;
                          if (snapshot.hasData) {
                            totalItems = snapshot.data!.docs.length;
                          }

                          if (totalItems == 0) return const SizedBox.shrink();

                          return Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Color(0xFFFFB800),
                                  shape: BoxShape.circle),
                              child: Text(
                                "$totalItems",
                                style: const TextStyle(
                                    fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- ISI KONTEN ---
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 25),
                  // --- BANNER SECTION ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 5),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFFB800),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Text("Home Made",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(height: 15),
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                                fontFamily: 'Serif',
                                fontSize: 38,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF422817),
                                height: 0),
                            children: [
                              TextSpan(text: "Keripik "),
                              TextSpan(
                                  text: "Kentang\n",
                                  style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w400)),
                              TextSpan(text: "bikin\nKetagihan"),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          "Dibuat dari kentang asli pilihan dengan bumbu rahasia yang melimpah. Renyahnya juara, gurihnya kerasa!",
                          style: TextStyle(
                              color: Color(0xFF5A3821),
                              fontSize: 16,
                              height: 1.5),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- CATEGORY BAR ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 25),
                    color: const Color(0xFF5A3821),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildCategoryItem("Semua"),
                        _buildCategoryItem("Pedas"),
                        _buildCategoryItem("Gurih"),
                      ],
                    ),
                  ),

                  // --- PRODUCT GRID DARI DATABASE FIRESTORE ---
                  Padding(
                    padding: const EdgeInsets.all(25.0),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('products')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(
                                  color: Color(0xFF422817)),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text("Tidak ada produk tersedia",
                                  style: TextStyle(color: Color(0xFF422817))),
                            ),
                          );
                        }

                        final allProducts = snapshot.data!.docs;
                        final filteredProducts = allProducts.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final String kategori = data['category'] ??
                              ''; // Mengikuti key 'category' dari panel admin
                          if (selectedCategory == "Semua") return true;
                          return kategori.toLowerCase() ==
                              selectedCategory.toLowerCase();
                        }).toList();

                        if (filteredProducts.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text("Produk kategori ini belum tersedia",
                                  style: TextStyle(color: Color(0xFF422817))),
                            ),
                          );
                        }

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final doc = filteredProducts[index];
                            final productModel = ProductModel.fromFirestore(
                                doc); // Konversi data dokumen menjadi objek model terstruktur

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DetailProductPage(
                                        product:
                                            productModel), // Terhubung dinamis membawa data parameter objek
                                  ),
                                );
                              },
                              child: _buildProductCard(
                                  productModel.namaProduk,
                                  productModel
                                      .imageUrl), // Mengurai field Base64 string image_url
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // --- TOMBOL LIHAT MENU KATALOG BAWAHAN ---
                  Center(
                    child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('products')
                            .limit(1)
                            .snapshots(),
                        builder: (context, snapshot) {
                          return GestureDetector(
                            onTap: () {
                              if (snapshot.hasData &&
                                  snapshot.data!.docs.isNotEmpty) {
                                final firstDoc = snapshot.data!.docs.first;
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 40),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 50, vertical: 15),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30)),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                              ),
                            ),
                          );
                        }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // --- NAVBAR ---
      bottomNavigationBar: Container(
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
            _buildNavItem(0, Icons.home_outlined, "Beranda"),
            _buildNavItem(1, Icons.receipt_long_outlined, "Riwayat Pesanan"),
            _buildNavItem(2, Icons.person_outline, "Akun"),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(String title) {
    bool isSelected = selectedCategory == title;
    return GestureDetector(
      onTap: () => setState(() => selectedCategory = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFB800)
              : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildProductCard(String title, String imageString) {
    // Alur penanganan gambar dari tipe string Base64 Data URI panel admin secara aman
    Widget imageWidget;
    try {
      if (imageString.startsWith("data:image")) {
        final base64String = imageString.split(',').last;
        imageWidget = Image.memory(
          base64Decode(base64String),
          fit: BoxFit.cover,
          width: double.infinity,
        );
      } else {
        imageWidget = const Center(
          child:
              Icon(Icons.cookie_outlined, size: 50, color: Color(0xFF8B5E3C)),
        );
      }
    } catch (e) {
      imageWidget = const Center(
        child: Icon(Icons.broken_image, size: 50, color: Color(0xFF8B5E3C)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEFE6D5),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF422817).withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              child: imageWidget,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF422817),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCardDummy(String title, String imageUrl) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEFE6D5),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF422817).withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                              child: Icon(Icons.cookie_outlined,
                                  size: 50, color: Color(0xFF8B5E3C))))
                  : const Center(
                      child: Icon(Icons.cookie_outlined,
                          size: 50, color: Color(0xFF8B5E3C))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF422817),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onNavTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFFE082) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: const Color(0xFF422817)),
          ),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF422817),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
