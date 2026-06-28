import 'dart:convert'; // Ditambahkan untuk penanganan konversi Base64
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart'; // Ditambahkan untuk mengambil gambar dari galeri

class EditProductPage extends StatefulWidget {
  final String productId; // Menerima ID Dokumen Produk dari halaman sebelumnya

  const EditProductPage({super.key, required this.productId});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  // ==========================================
  // PALET WARNA (Sesuai Brand Keripik)
  // ==========================================
  final Color primaryYellow = const Color(0xFFFFB800);
  final Color bgLight = const Color(0xFFFDF5E6);
  final Color darkBrown = const Color(0xFF422817);
  final Color fieldColor = const Color(0xFFF1EDE7);
  final Color textGrey = const Color(0xFF8E8E8E);

  // Controller untuk menangkap input teks
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();

  // Controller untuk Baris Varian Ukuran (Harga & Stok)
  final TextEditingController _price100gController = TextEditingController();
  final TextEditingController _stock100gController = TextEditingController();

  final TextEditingController _price250gController = TextEditingController();
  final TextEditingController _stock250gController = TextEditingController();

  final TextEditingController _price500gController = TextEditingController();
  final TextEditingController _stock500gController = TextEditingController();

  final TextEditingController _price1kgController = TextEditingController();
  final TextEditingController _stock1kgController = TextEditingController();

  bool _isAvailable = true;
  bool _isLoading = true;
  String _selectedCategory = 'Gurih';
  final List<String> _variants = ['Original', 'Balado', 'BBQ', 'Pedas Manis'];
  final List<String> _selectedVariants = [];

  // Variabel untuk menampung data gambar lokal atau gambar lama dari database
  File? _imageFile;
  String? _currentBase64Uri;

  @override
  void initState() {
    super.initState();
    _loadProductData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _price100gController.dispose();
    _stock100gController.dispose();
    _price250gController.dispose();
    _stock250gController.dispose();
    _price500gController.dispose();
    _stock500gController.dispose();
    _price1kgController.dispose();
    _stock1kgController.dispose();
    super.dispose();
  }

  // Fungsi mengambil gambar baru dari galeri sistem handphone
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _currentBase64Uri =
            null; // Reset string lama karena ada gambar baru lokal
      });
    }
  }

  // Fungsi memuat data produk secara real-time dari Firestore
  Future<void> _loadProductData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _skuController.text = data['sku'] ?? '';
          _selectedCategory = data['category'] ?? 'Gurih';
          _isAvailable = data['isAvailable'] ?? true;

          // Memuat string Base64 gambar lama dari database jika tersedia
          _currentBase64Uri = data['image_url'];

          // Memuat varian rasa terpilih
          if (data['selectedVariants'] != null) {
            _selectedVariants.clear();
            _selectedVariants
                .addAll(List<String>.from(data['selectedVariants']));
          }

          // Memuat harga & stok berdasarkan gramasi dari map database
          Map<String, dynamic> sizes = data['sizes'] ?? {};

          _price100gController.text =
              sizes['100G']?['price']?.toString() ?? '15000';
          _stock100gController.text =
              sizes['100G']?['stock']?.toString() ?? '0';

          _price250gController.text =
              sizes['250G']?['price']?.toString() ?? '35000';
          _stock250gController.text =
              sizes['250G']?['stock']?.toString() ?? '0';

          _price500gController.text =
              sizes['500G']?['price']?.toString() ?? '65000';
          _stock500gController.text =
              sizes['500G']?['stock']?.toString() ?? '0';

          _price1kgController.text =
              sizes['1KG']?['price']?.toString() ?? '120000';
          _stock1kgController.text = sizes['1KG']?['stock']?.toString() ?? '0';

          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal memuat data: $e")),
      );
    }
  }

  // Fungsi untuk menyimpan perubahan data produk ke Firestore
  Future<void> _updateProduct() async {
    setState(() => _isLoading = true);

    // Menghitung total stok keseluruhan dari gabungan setiap ukuran produk
    int totalStock = (int.tryParse(_stock100gController.text) ?? 0) +
        (int.tryParse(_stock250gController.text) ?? 0) +
        (int.tryParse(_stock500gController.text) ?? 0) +
        (int.tryParse(_stock1kgController.text) ?? 0);

    // Mengambil patokan harga terendah untuk ditampilkan pada list katalog utama admin
    String displayPrice =
        _price100gController.text.isNotEmpty ? _price100gController.text : "0";

    try {
      String finalImageUrl = _currentBase64Uri ?? "";

      // Jika admin memilih foto baru dari galeri, ubah file tersebut menjadi string Base64
      if (_imageFile != null) {
        List<int> imageBytes = await _imageFile!.readAsBytes();
        String base64Image = base64Encode(imageBytes);
        finalImageUrl = "data:image/jpeg;base64,$base64Image";
      }

      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .update({
        'name': _nameController.text.trim(),
        'sku': _skuController.text.trim(),
        'category': _selectedCategory,
        'selectedVariants': _selectedVariants,
        'isAvailable': _isAvailable,
        'stock':
            totalStock, // sinkronisasi otomatis field stok halaman kelola produk
        'price': displayPrice.trim(),
        'image_url':
            finalImageUrl, // Menyimpan teks Base64 baru atau mempertahankan teks lama
        'sizes': {
          '100G': {
            'price': int.tryParse(_price100gController.text) ?? 15000,
            'stock': int.tryParse(_stock100gController.text) ?? 0,
          },
          '250G': {
            'price': int.tryParse(_price250gController.text) ?? 35000,
            'stock': int.tryParse(_stock250gController.text) ?? 0,
          },
          '500G': {
            'price': int.tryParse(_price500gController.text) ?? 65000,
            'stock': int.tryParse(_stock500gController.text) ?? 0,
          },
          '1KG': {
            'price': int.tryParse(_price1kgController.text) ?? 120000,
            'stock': int.tryParse(_stock1kgController.text) ?? 0,
          },
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Perubahan produk berhasil disimpan!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menyimpan perubahan: $e")),
        );
      }
    }
  }

  // Fungsi untuk menghapus produk secara permanen dari halaman detail edit
  Future<void> _deleteProduct() async {
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
              Navigator.pop(context); // Tutup dialog
              await FirebaseFirestore.instance
                  .collection('products')
                  .doc(widget.productId)
                  .delete();
              if (mounted) {
                Navigator.pop(
                    context); // Kembali ke halaman utama kelola produk
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Produk berhasil dihapus")),
                );
              }
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgLight,
        body: const Center(
            child: CircularProgressIndicator(color: Color(0xFF422817))),
      );
    }

    // Penanganan tampilan visual preview gambar secara kondisional
    Widget imagePreviewWidget;
    if (_imageFile != null) {
      // Menampilkan gambar baru yang baru saja dipilih admin dari galeri
      imagePreviewWidget = ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Image.file(_imageFile!,
            fit: BoxFit.cover, width: double.infinity, height: double.infinity),
      );
    } else if (_currentBase64Uri != null &&
        _currentBase64Uri!.startsWith("data:image")) {
      // Menampilkan gambar lama berwujud teks Base64 string yang diambil dari Firestore
      try {
        final base64String = _currentBase64Uri!.split(',').last;
        imagePreviewWidget = ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Image.memory(base64Decode(base64String),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity),
        );
      } catch (e) {
        imagePreviewWidget = _buildDefaultPhotoPlaceholder();
      }
    } else {
      imagePreviewWidget = _buildDefaultPhotoPlaceholder();
    }

    return Scaffold(
      backgroundColor: bgLight,
      body: Column(
        children: [
          // --- TOP BAR CUSTOM (Sama dengan Dashboard & Home) ---
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
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: darkBrown),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "Edit Produk",
                      style: TextStyle(
                          color: darkBrown,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed:
                      _updateProduct, // Mengaktifkan fungsi simpan database
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryYellow,
                    foregroundColor: darkBrown,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text("Simpan",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),

          // --- ISI KONTEN (SCROLLABLE) ---
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // --- AREA GANTI FOTO (Memicu picker sistem tanpa storage) ---
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: fieldColor,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: imagePreviewWidget,
                    ),
                  ),
                  const SizedBox(height: 25),

                  // --- FORM INPUT UTAMA ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("Nama Produk"),
                        _buildTextField(
                            "Keripik Kentang Original", _nameController),
                        const SizedBox(height: 20),

                        _buildLabel("Kategori"),
                        _buildDropdown(),
                        const SizedBox(height: 20),

                        _buildLabel("Varian Rasa"),
                        Wrap(
                          spacing: 8,
                          children: _variants
                              .map((v) => _buildVariantChip(v))
                              .toList(),
                        ),
                        const SizedBox(height: 10),
                        const Divider(),
                        const SizedBox(height: 10),

                        // --- INPUT HARGA & STOK ---
                        Row(
                          children: [
                            Expanded(child: _buildLabel("Harga (Rp)")),
                            Expanded(child: _buildLabel("Stok (Pcs)")),
                          ],
                        ),
                        _buildPriceStockRow("100 GRAM", _price100gController,
                            _stock100gController),
                        _buildPriceStockRow("250 GRAM", _price250gController,
                            _stock250gController),
                        _buildPriceStockRow("500 GRAM", _price500gController,
                            _stock500gController),
                        _buildPriceStockRow("1 KILOGRAM", _price1kgController,
                            _stock1kgController),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- INVENTARIS & STATUS ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Inventaris & Status",
                            style: TextStyle(
                                color: textGrey,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        const SizedBox(height: 15),
                        _buildLabel("SKU"),
                        _buildTextField("KK-ORI-01", _skuController),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: fieldColor,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.visibility_outlined, color: darkBrown),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Status Produk",
                                        style: TextStyle(
                                            color: darkBrown,
                                            fontWeight: FontWeight.bold)),
                                    Text("Tampilkan di toko",
                                        style: TextStyle(
                                            color: textGrey, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _isAvailable,
                                activeColor: primaryYellow,
                                onChanged: (val) =>
                                    setState(() => _isAvailable = val),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- TOMBOL HAPUS (Aktif Terhubung Ke Firestore) ---
                  TextButton.icon(
                    onPressed: _deleteProduct,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text("Hapus Produk Ini",
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER ---

  Widget _buildDefaultPhotoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo_outlined, color: darkBrown, size: 40),
        const SizedBox(height: 10),
        Text("Ganti Foto Produk",
            style: TextStyle(color: darkBrown, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: TextStyle(
              color: darkBrown, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: fieldColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
          color: fieldColor, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          items: ['Gurih', 'Pedas'].map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
          onChanged: (val) => setState(() => _selectedCategory = val!),
        ),
      ),
    );
  }

  Widget _buildVariantChip(String label) {
    bool isSelected = _selectedVariants.contains(label);
    return FilterChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? darkBrown : textGrey)),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          val ? _selectedVariants.add(label) : _selectedVariants.remove(label);
        });
      },
      selectedColor: primaryYellow,
      backgroundColor: fieldColor,
      checkmarkColor: darkBrown,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    );
  }

  Widget _buildPriceStockRow(String size, TextEditingController priceController,
      TextEditingController stockController) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(size,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(child: _buildTextField("Harga", priceController)),
              const SizedBox(width: 10),
              Expanded(child: _buildTextField("Stok", stockController)),
            ],
          ),
        ],
      ),
    );
  }
}
