import 'dart:convert'; // Ditambahkan untuk men-decode data string Base64 menjadi file memory
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_admin.dart';
import 'order_list.dart';
import 'edit_product.dart';
import 'add_product.dart';

class ManageProductPage extends StatefulWidget {
  const ManageProductPage({super.key});

  @override
  State<ManageProductPage> createState() => _ManageProductPageState();
}

class _ManageProductPageState extends State<ManageProductPage> {
  final Color primaryYellow = const Color(0xFFFFB800);
  final Color bgLight = const Color(0xFFFDF5E6);
  final Color darkBrown = const Color(0xFF422817);
  final Color textGrey = const Color(0xFF8E8E8E);
  final Color cardColor = Colors.white;

  int _currentIndex = 1;
  int _currentPage = 1;
  final int _itemsPerPage =
      4; // Menyesuaikan batas tampilan halaman visual bawaan
  String _searchQuery = "";

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    if (index == 0) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const DashboardAdminPage()));
    } else if (index == 2) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const OrderListPage()));
    }
  }

  // Fungsi untuk menghapus produk dari database Firestore
  void _deleteProduct(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Produk"),
        content: const Text(
            "Apakah Anda yakin ingin menghapus produk ini dari katalog?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance
                  .collection('products')
                  .doc(docId)
                  .delete();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Produk berhasil dihapus")),
              );
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: Column(
        children: [
          // --- TOP BAR (Sesuai gaya Dashboard Admin agar tetap statis) ---
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
                    Image.asset(
                      'assets/images/logo.png',
                      height: 40,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.cookie, color: primaryYellow, size: 30),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "ADMIN",
                      style: TextStyle(
                          color: darkBrown,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),

          // --- ISI KONTEN (SCROLLABLE & REAL-TIME) ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF422817)));
                }

                List<QueryDocumentSnapshot> allProducts =
                    snapshot.data?.docs ?? [];

                // Sistem Filter berdasarkan input Search Bar
                if (_searchQuery.isNotEmpty) {
                  allProducts = allProducts.where((doc) {
                    String name =
                        (doc.data() as Map<String, dynamic>)['name'] ?? "";
                    return name
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase());
                  }).toList();
                }

                int totalProducts = allProducts.length;
                int totalPages = (totalProducts / _itemsPerPage).ceil();
                if (totalPages == 0) totalPages = 1;

                // Penyesuaian jangkauan index item halaman saat ini
                int startIndex = (_currentPage - 1) * _itemsPerPage;
                int endIndex = startIndex + _itemsPerPage;
                if (endIndex > totalProducts) endIndex = totalProducts;

                List<QueryDocumentSnapshot> paginatedProducts = [];
                if (startIndex < totalProducts) {
                  paginatedProducts = allProducts.sublist(startIndex, endIndex);
                }

                return Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- SEARCH BAR & ADD BUTTON ---
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 15),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(30),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: TextField(
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                        _currentPage =
                                            1; // Reset halaman ke awal saat mengetik pencarian
                                      });
                                    },
                                    decoration: const InputDecoration(
                                      hintText: "Cari produk...",
                                      border: InputBorder.none,
                                      icon: Icon(Icons.search,
                                          color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Container(
                                decoration: BoxDecoration(
                                    color: primaryYellow,
                                    borderRadius: BorderRadius.circular(15)),
                                child: IconButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const AddProductPage()),
                                    );
                                  },
                                  icon: const Icon(Icons.add,
                                      color: Colors.black, size: 30),
                                ),
                              )
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Kelola Produk",
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: darkBrown)),
                              Text("Pantau stok dan kelola katalog Anda.",
                                  style:
                                      TextStyle(color: textGrey, fontSize: 14)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // --- LIST ITEM PRODUK DARI FIRESTORE ---
                        Expanded(
                          child: paginatedProducts.isEmpty
                              ? Center(
                                  child: Text("Tidak ada produk ditemukan.",
                                      style: TextStyle(
                                          color: textGrey, fontSize: 14)),
                                )
                              : ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.only(
                                      left: 20, right: 20, bottom: 130),
                                  itemCount: paginatedProducts.length,
                                  itemBuilder: (context, index) {
                                    var doc = paginatedProducts[index];
                                    var data =
                                        doc.data() as Map<String, dynamic>;

                                    String name = data['name'] ?? "No Name";
                                    String price =
                                        data['price']?.toString() ?? "0";
                                    int stock = data['stock'] ?? 0;
                                    int maxStock = data['maxStock'] ??
                                        20; // Batas pembagi persentase bar indikator

                                    double progress = stock / maxStock;
                                    if (progress > 1.0) progress = 1.0;
                                    if (progress < 0.0) progress = 0.0;

                                    bool isLowStock = stock <= 3;

                                    // Mengambil data teks Base64 uri dari field image_url
                                    String imageUrlString =
                                        data['image_url'] ?? "";

                                    // Membuat tags kategori visual bawaan dari field database
                                    List<String> tags = [];
                                    if (data['category'] != null) {
                                      tags.add(data['category']
                                          .toString()
                                          .toUpperCase());
                                    } else {
                                      tags.add("UMUM");
                                    }

                                    return _buildProductItem(
                                      name,
                                      price,
                                      stock,
                                      progress,
                                      tags,
                                      isLowStock,
                                      imageUrlString, // Kirim string Base64 ke fungsi pembuat card
                                      onEdit: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  EditProductPage(
                                                      productId: doc.id)),
                                        );
                                      },
                                      onDelete: () => _deleteProduct(doc.id),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),

                    // --- PAGINATION MELAYANG ---
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              bgLight,
                              bgLight,
                              bgLight.withOpacity(0.0)
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                totalProducts == 0
                                    ? "0 PRODUK"
                                    : "${startIndex + 1}-$endIndex DARI $totalProducts PRODUK",
                                style: TextStyle(
                                    color: textGrey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildPageBtn("<", false, onTap: () {
                                  if (_currentPage > 1) {
                                    setState(() => _currentPage--);
                                  }
                                }),
                                // Generate tombol halaman dinamis mengikuti isi database dokumen
                                ...List.generate(totalPages, (index) {
                                  int pageNum = index + 1;
                                  return _buildPageBtn(pageNum.toString(),
                                      _currentPage == pageNum, onTap: () {
                                    setState(() => _currentPage = pageNum);
                                  });
                                }),
                                _buildPageBtn(">", false, onTap: () {
                                  if (_currentPage < totalPages) {
                                    setState(() => _currentPage++);
                                  }
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildProductItem(String title, String price, int stock,
      double progress, List<String> tags, bool isLowStock, String base64Uri,
      {VoidCallback? onEdit, VoidCallback? onDelete}) {
    // Logic pemisah data URI header "data:image/jpeg;base64," agar aman di-decode oleh flutter
    Widget imageWidget;
    try {
      if (base64Uri.startsWith("data:image")) {
        final base64String = base64Uri.split(',').last;
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.memory(
            base64Decode(base64String),
            fit: BoxFit.cover,
            width: 85,
            height: 85,
          ),
        );
      } else {
        // Fallback ke ikon default bawaan jika data string kosong / rusak
        imageWidget = Icon(Icons.fastfood_outlined,
            color: darkBrown.withOpacity(0.3), size: 30);
      }
    } catch (e) {
      imageWidget = Icon(Icons.fastfood_outlined,
          color: darkBrown.withOpacity(0.3), size: 30);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 85,
            height: 85,
            decoration: BoxDecoration(
                color: const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(20)),
            child:
                imageWidget, // Menampilkan widget foto dari Firestore secara langsung
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: tags
                      .map((tag) => Container(
                            margin: const EdgeInsets.only(right: 5),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: tag == "BEST"
                                    ? darkBrown
                                    : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(tag,
                                style: TextStyle(
                                    color: tag == "BEST"
                                        ? Colors.white
                                        : Colors.orange.shade900,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 5),
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkBrown,
                        fontSize: 16)),
                Text("Rp $price",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkBrown,
                        fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("STOK",
                        style: TextStyle(
                            fontSize: 9,
                            color: textGrey,
                            fontWeight: FontWeight.bold)),
                    Text("$stock Pcs",
                        style: TextStyle(
                            fontSize: 9,
                            color: isLowStock ? Colors.red : darkBrown,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade100,
                    color: isLowStock ? Colors.red : primaryYellow,
                    minHeight: 5,
                  ),
                )
              ],
            ),
          ),
          const SizedBox(width: 5),
          Column(
            children: [
              IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined,
                      color: Colors.grey, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints()),
              const SizedBox(height: 10),
              IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints()),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPageBtn(String label, bool active, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
            color: active ? darkBrown : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              if (!active)
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
            ],
            border:
                Border.all(color: active ? darkBrown : Colors.grey.shade300)),
        child: Center(
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: active ? Colors.white : Colors.grey))),
      ),
    );
  }

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
      onTap: () => _onTabTapped(index),
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
