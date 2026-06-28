import 'dart:convert'; // Ditambahkan untuk konversi Base64
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final Color primaryYellow = const Color(0xFFFFB800);
  final Color bgLight = const Color(0xFFFDF5E6);
  final Color darkBrown = const Color(0xFF422817);
  final Color fieldColor = const Color(0xFFF1EDE7);
  final Color textGrey = const Color(0xFF8E8E8E);

  // File Gambar
  File? _imageFile;
  bool _isUploading = false;

  // Controllers untuk input
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _price100g = TextEditingController(text: "15000");
  final TextEditingController _stock100g = TextEditingController(text: "0");
  final TextEditingController _price250g = TextEditingController(text: "35000");
  final TextEditingController _stock250g = TextEditingController(text: "0");
  final TextEditingController _price500g = TextEditingController(text: "65000");
  final TextEditingController _stock500g = TextEditingController(text: "0");
  final TextEditingController _price1kg = TextEditingController(text: "120000");
  final TextEditingController _stock1kg = TextEditingController(text: "0");

  bool _isAvailable = true;
  String _selectedCategory = 'Gurih';
  final List<String> _variants = ['Original', 'Balado', 'BBQ', 'Pedas Manis'];
  final List<String> _selectedVariants = ['Original'];

  // Fungsi pilih gambar
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // Fungsi menyimpan data ke Firestore langsung menggunakan Base64 String tanpa Storage
  Future<void> _saveProduct() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nama produk harus diisi!")));
      return;
    }
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Foto produk wajib diunggah!")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      // PROSES KONVERSI: Mengubah file gambar lokal menjadi teks string Base64
      List<int> imageBytes = await _imageFile!.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      // Membuat format data URI agar string Base64 bisa langsung dibaca widget Image.network di aplikasi pembeli
      String base64DataUri = "data:image/jpeg;base64,$base64Image";

      int totalStock = (int.tryParse(_stock100g.text) ?? 0) +
          (int.tryParse(_stock250g.text) ?? 0) +
          (int.tryParse(_stock500g.text) ?? 0) +
          (int.tryParse(_stock1kg.text) ?? 0);

      // Simpan data langsung ke Firestore
      await FirebaseFirestore.instance.collection('products').add({
        'name': _nameController.text.trim(),
        'sku': _skuController.text.trim(),
        'category': _selectedCategory,
        'selectedVariants': _selectedVariants,
        'isAvailable': _isAvailable,
        'stock': totalStock,
        'image_url':
            base64DataUri, // Menyimpan string teks panjang Base64 ke dalam kolom image_url
        'price': _price100g.text.trim(),
        'sizes': {
          '100G': {
            'price': int.tryParse(_price100g.text) ?? 0,
            'stock': int.tryParse(_stock100g.text) ?? 0
          },
          '250G': {
            'price': int.tryParse(_price250g.text) ?? 0,
            'stock': int.tryParse(_stock250g.text) ?? 0
          },
          '500G': {
            'price': int.tryParse(_price500g.text) ?? 0,
            'stock': int.tryParse(_stock500g.text) ?? 0
          },
          '1KG': {
            'price': int.tryParse(_price1kg.text) ?? 0,
            'stock': int.tryParse(_stock1kg.text) ?? 0
          },
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Produk berhasil ditambahkan!")));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error sistem internal: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Gagal menyimpan data: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2))
            ]),
            padding:
                const EdgeInsets.only(left: 20, right: 20, top: 50, bottom: 15),
            child: Row(
              children: [
                IconButton(
                    icon: Icon(Icons.arrow_back, color: darkBrown),
                    onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 5),
                Text("Tambah Produk",
                    style: TextStyle(
                        color: darkBrown,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                          color: fieldColor,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.white, width: 4)),
                      child: _imageFile == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                  Icon(Icons.add_a_photo_outlined,
                                      color: darkBrown, size: 40),
                                  const SizedBox(height: 10),
                                  Text("Pilih Foto Produk",
                                      style: TextStyle(
                                          color: darkBrown,
                                          fontWeight: FontWeight.w500)),
                                ])
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(21),
                              child:
                                  Image.file(_imageFile!, fit: BoxFit.cover)),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Nama Produk"),
                          _buildTextField(
                              _nameController, "Contoh: Keripik Kentang"),
                          const SizedBox(height: 20),
                          _buildLabel("Kategori"),
                          _buildDropdown(),
                          const SizedBox(height: 20),
                          _buildLabel("Varian Rasa"),
                          Wrap(
                              spacing: 8,
                              children: _variants
                                  .map((v) => _buildVariantChip(v))
                                  .toList()),
                          const SizedBox(height: 10),
                          const Divider(),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: _buildLabel("Harga (Rp)")),
                            Expanded(child: _buildLabel("Stok (Pcs)"))
                          ]),
                          _buildPriceStockRow(
                              "100 GRAM", _price100g, _stock100g),
                          _buildPriceStockRow(
                              "250 GRAM", _price250g, _stock250g),
                          _buildPriceStockRow(
                              "500 GRAM", _price500g, _stock500g),
                          _buildPriceStockRow(
                              "1 KILOGRAM", _price1kg, _stock1kg),
                        ]),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30)),
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
                          _buildTextField(_skuController, "Contoh: KK-001"),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: fieldColor,
                                borderRadius: BorderRadius.circular(15)),
                            child: Row(children: [
                              Icon(Icons.visibility_outlined, color: darkBrown),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text("Status Produk",
                                        style: TextStyle(
                                            color: darkBrown,
                                            fontWeight: FontWeight.bold)),
                                    Text("Tampilkan di toko",
                                        style: TextStyle(
                                            color: textGrey, fontSize: 12)),
                                  ])),
                              Switch(
                                  value: _isAvailable,
                                  activeColor: primaryYellow,
                                  onChanged: (val) =>
                                      setState(() => _isAvailable = val))
                            ]),
                          )
                        ]),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30), topRight: Radius.circular(30))),
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _isUploading ? null : _saveProduct,
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryYellow,
                foregroundColor: darkBrown,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15))),
            child: _isUploading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Simpan Produk",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: TextStyle(
              color: darkBrown, fontWeight: FontWeight.bold, fontSize: 14)));

  Widget _buildTextField(TextEditingController controller, String hint) =>
      TextField(
        controller: controller,
        decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: fieldColor,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 12)),
      );

  Widget _buildDropdown() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
            color: fieldColor, borderRadius: BorderRadius.circular(12)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedCategory,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down),
            items: ['Gurih', 'Pedas']
                .map((String value) =>
                    DropdownMenuItem<String>(value: value, child: Text(value)))
                .toList(),
            onChanged: (val) => setState(() => _selectedCategory = val!),
          ),
        ),
      );

  Widget _buildVariantChip(String label) {
    bool isSelected = _selectedVariants.contains(label);
    return FilterChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? darkBrown : textGrey)),
      selected: isSelected,
      onSelected: (val) => setState(() =>
          val ? _selectedVariants.add(label) : _selectedVariants.remove(label)),
      selectedColor: primaryYellow,
      backgroundColor: fieldColor,
      checkmarkColor: darkBrown,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    );
  }

  Widget _buildPriceStockRow(String size, TextEditingController priceC,
          TextEditingController stockC) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(size,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          const SizedBox(height: 5),
          Row(children: [
            Expanded(child: _buildTextField(priceC, "")),
            const SizedBox(width: 10),
            Expanded(child: _buildTextField(stockC, ""))
          ]),
        ]),
      );
}
