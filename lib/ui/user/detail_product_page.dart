import 'dart:convert'; // Kunci utama untuk mendecode gambar teks Base64 dari Firestore
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // FIX UTAMA (image_d2c7a5.png): Import wajib agar fungsi NumberFormat aktif bebas error!
import 'cart_page.dart'; // Pastikan file ini ada di folder yang sama
import '../../models/product_model.dart'; // Import model produk Anda

class DetailProductPage extends StatefulWidget {
  final ProductModel
      product; // Menerima parameter objek produk dinamis dari halaman home

  const DetailProductPage({super.key, required this.product});

  @override
  State<DetailProductPage> createState() => _DetailProductPageState();
}

class _DetailProductPageState extends State<DetailProductPage> {
  // --- STATE UNTUK UI ---
  late String selectedVarian;
  String selectedSize =
      "100G"; // Diselaraskan dengan key kapital database ('100G', '250G', '500G', '1KG')
  int quantity = 1;
  bool isAddingToCart = false;

  // --- TEMA WARNA ---
  final Color primaryYellow = const Color(0xFFFFB800);
  final Color bgLight = const Color(0xFFFDF5E6);
  final Color greyChip = const Color(0xFFE8E8E8);
  final Color textBrown = const Color(0xFF422817);
  final Color cardBorder = const Color.fromARGB(255, 230, 196, 163);
  final Color textGrey =
      const Color(0xFF8E8E8E); // Deklarasi textGrey aman bebas error

  @override
  void initState() {
    super.initState();
    // Mengambil varian rasa pertama secara dinamis dari database produk
    selectedVarian = widget.product.varianRasa.isNotEmpty
        ? widget.product.varianRasa.first
        : "Original";
  }

  // --- FUNGSI DINAMIS: MENGAMBIL HARGA ASLI TRANSAKSI DARI INPUT FIRESTORE ADMIN ---
  int _getPrice(String sizeKey) {
    Map<String, dynamic> sizeMap = widget.product.sizes[sizeKey] ?? {};
    return sizeMap['price'] ?? 0; // Menarik nilai int harga secara real-time
  }

  // --- FUNGSI DINAMIS: MENGAMBIL JUMLAH STOK PER UKURAN DARI DATABASE ---
  int _getStock(String sizeKey) {
    Map<String, dynamic> sizeMap = widget.product.sizes[sizeKey] ?? {};
    return sizeMap['stock'] ??
        0; // Menarik nilai int stock per ukuran dari Firestore
  }

  // --- FUNGSI AKTIF: TAMBAH KE SUB-KOLEKSI CART DATABASE_SERVICE.DART ---
  Future<void> _addToCart() async {
    // Validasi pengecekan apakah varian ukuran yang dipilih saat ini stoknya habis
    int currentAvailableStock = _getStock(selectedSize);
    if (currentAvailableStock <= 0) {
      _showSnippet("Maaf, stok kemasan $selectedSize saat ini sedang habis!");
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnippet("Silakan login terlebih dahulu");
      return;
    }

    setState(() => isAddingToCart = true);

    try {
      final CollectionReference cartRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart'); // Sinkron dengan sub-koleksi cart pembeli

      // ID unik kombinasi agar item dengan varian rasa & ukuran kemasan yang sama otomatis terakumulasi
      String cartDocId =
          "${widget.product.id}_${selectedVarian.toLowerCase().replaceAll(' ', '_')}_$selectedSize";
      DocumentSnapshot cartDoc = await cartRef.doc(cartDocId).get();

      int hargaSatuan = _getPrice(selectedSize);

      // Konversi ukuran string ke bentuk integer gram untuk kalkulator otomatis ongkos kirim ekspedisi
      int beratGram = 100;
      if (selectedSize == "250G") beratGram = 250;
      if (selectedSize == "500G") beratGram = 500;
      if (selectedSize == "1KG") beratGram = 1000;

      if (cartDoc.exists) {
        int currentQty =
            (cartDoc.data() as Map<String, dynamic>)['jumlah'] ?? 0;

        // Proteksi tambahan agar jumlah di keranjang tidak melebihi stok admin
        if (currentQty + quantity > currentAvailableStock) {
          _showSnippet(
              "Gagal! Jumlah keranjang melebihi total stok yang tersedia.");
          setState(() => isAddingToCart = false);
          return;
        }

        await cartRef.doc(cartDocId).update({
          'jumlah': currentQty + quantity,
        });
      } else {
        // Menyimpan field terstruktur sesuai blueprint fungsi addToCart database_service
        await cartRef.doc(cartDocId).set({
          'productId': widget.product.id,
          'namaProduk': widget.product.namaProduk,
          'rasa': selectedVarian,
          'ukuran': selectedSize,
          'hargaSatuan': hargaSatuan,
          'jumlah': quantity,
          'beratGram': beratGram,
          'image_url': widget.product
              .imageUrl, // Menyimpan teks Base64 gambar agar bisa di-load pembeli
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      setState(() => isAddingToCart = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "$selectedVarian ($selectedSize) berhasil ditambah ke keranjang!"),
            backgroundColor: textBrown,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CartPage()),
        );
      }
    } catch (e) {
      setState(() => isAddingToCart = false);
      if (mounted) {
        _showSnippet("Gagal menambahkan ke keranjang: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Alur penanganan decoder teks Base64 gambar milik produk secara aman agar tidak memicu memory hang
    Widget productImageWidget;
    try {
      if (widget.product.imageUrl.startsWith("data:image")) {
        final base64String = widget.product.imageUrl.split(',').last;
        productImageWidget = Image.memory(
          base64Decode(base64String),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } else {
        productImageWidget = Icon(Icons.cookie_outlined,
            size: 60, color: textBrown.withOpacity(0.6));
      }
    } catch (e) {
      productImageWidget = Icon(Icons.broken_image_outlined,
          size: 60, color: textBrown.withOpacity(0.6));
    }

    // Cek status ketersediaan stok ukuran yang dipilih saat ini aktif untuk tombol bawah
    int selectedSizeStock = _getStock(selectedSize);
    bool isOutOfStock = selectedSizeStock <= 0;

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textBrown),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Detail Produk",
          style: TextStyle(
              color: textBrown, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              icon: Icon(Icons.shopping_cart_outlined,
                  color: textBrown, size: 28),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartPage()),
                );
              },
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER GAMBAR DINAMIS BASE64 ---
            Container(
              width: double.infinity,
              height: 280,
              decoration: const BoxDecoration(color: Color(0xFFEBE8E1)),
              child: productImageWidget,
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- JUDUL PRODUK ---
                  Text(
                    widget.product.namaProduk.toUpperCase(),
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: textBrown,
                        height: 1.1),
                  ),
                  const SizedBox(height: 4),


                  const SizedBox(height: 35),

                  // --- VARIAN RASA LIVE DARI DATABASE ---
                  const Text("Varian Rasa",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 15),
                  widget.product.varianRasa.isEmpty
                      ? Text("Belum ada varian rasa aktif",
                          style: TextStyle(
                              color: textGrey, fontStyle: FontStyle.italic))
                      : Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: widget.product.varianRasa
                              .map((v) => _buildVarianChip(v))
                              .toList(),
                        ),

                  const SizedBox(height: 35),

                  // --- UKURAN KEMASAN (DENGAN KONDISI "HABIS" JIKA STOK 0) ---
                  const Text("Ukuran Kemasan",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 15),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.8,
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,
                    children: [
                      _buildSizeCard("100G"),
                      _buildSizeCard("250G"),
                      _buildSizeCard("500G"),
                      _buildSizeCard("1KG"),
                    ],
                  ),

                  const SizedBox(height: 35),

                  // --- QUANTITY SELECTOR (DISABLED JIKA HABIS) ---
                  Row(
                    children: [
                      const Text("Jumlah",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(width: 25),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: isOutOfStock ? textGrey : textBrown,
                              width: 1.5),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: isOutOfStock
                                  ? null
                                  : () {
                                      if (quantity > 1) {
                                        setState(() => quantity--);
                                      }
                                    },
                              icon: Icon(Icons.remove,
                                  size: 20,
                                  color:
                                      isOutOfStock ? textGrey : Colors.black),
                            ),
                            Text(
                              isOutOfStock ? "0" : "$quantity",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isOutOfStock ? textGrey : Colors.black),
                            ),
                            IconButton(
                              onPressed: isOutOfStock
                                  ? null
                                  : () {
                                      if (quantity < selectedSizeStock) {
                                        setState(() => quantity++);
                                      } else {
                                        _showSnippet(
                                            "Batas maksimal stok tercapai!");
                                      }
                                    },
                              icon: Icon(Icons.add,
                                  size: 20,
                                  color:
                                      isOutOfStock ? textGrey : Colors.black),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),

                  const SizedBox(height: 40),

                  // --- BUTTON TAMBAH KE KERANJANG (OTOMATIS LOCK & GRAY JIKA HABIS) ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed:
                          (isAddingToCart || isOutOfStock) ? null : _addToCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isOutOfStock ? Colors.grey.shade400 : primaryYellow,
                        elevation: isOutOfStock ? 0 : 4,
                        shadowColor: primaryYellow.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: isAddingToCart
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: textBrown, strokeWidth: 2),
                            )
                          : Text(
                              isOutOfStock
                                  ? "Stok Habis"
                                  : "Tambah Ke Keranjang",
                              style: TextStyle(
                                  color: isOutOfStock
                                      ? Colors.white
                                      : Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
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

  Widget _buildVarianChip(String label) {
    bool isSelected = selectedVarian == label;
    return GestureDetector(
      onTap: () => setState(() => selectedVarian = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryYellow : greyChip,
          borderRadius: BorderRadius.circular(25),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: primaryYellow.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isSelected ? Colors.black : Colors.black87,
          ),
        ),
      ),
    );
  }

  // Widget Pembuat Kartu Ukuran Kemasan dengan Deteksi Tulisan "Habis" jika Nilai Stok dari Admin adalah 0
  Widget _buildSizeCard(String sizeKey) {
    bool isSelected = selectedSize == sizeKey;
    int currentStock = _getStock(sizeKey);
    bool outOfStock = currentStock <= 0;

    String displayPriceText = outOfStock
        ? "Habis"
        : "Rp ${NumberFormat('#,###').format(_getPrice(sizeKey))}";

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedSize = sizeKey;
          quantity =
              1; // Reset kuantitas ke 1 setiap memindahkan varian gramasi kemasan
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: outOfStock
              ? Colors.grey.shade100
              : (isSelected ? const Color(0xFFFFD18B) : Colors.white),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
              color: outOfStock
                  ? Colors.grey.shade300
                  : (isSelected ? cardBorder : Colors.grey.shade300),
              width: 1.5),
          boxShadow: isSelected && !outOfStock
              ? [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 10)
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              sizeKey,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: outOfStock ? textGrey : Colors.black),
            ),
            const SizedBox(height: 2),
            Text(
              displayPriceText,
              style: TextStyle(
                  fontSize: 13,
                  color: outOfStock ? Colors.red.shade700 : Colors.black54,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnippet(String msg) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
