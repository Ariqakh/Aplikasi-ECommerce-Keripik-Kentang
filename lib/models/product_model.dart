import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String namaProduk;
  final String kategori;
  final List<String> varianRasa;
  final String imageUrl; // Tambahkan ini
  final String statusProduk;
  final Map<String, dynamic>
      sizes; // Sesuaikan dengan struktur Map di Firestore
  final int totalStock; // Sesuaikan dengan field 'stock' di Firestore

  ProductModel({
    required this.id,
    required this.namaProduk,
    required this.kategori,
    required this.varianRasa,
    required this.imageUrl,
    required this.statusProduk,
    required this.sizes,
    required this.totalStock,
  });

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id: doc.id,
      namaProduk:
          data['name'] ?? '', // Sesuaikan dengan key di Firestore ('name')
      kategori: data['category'] ?? '',
      varianRasa: List<String>.from(data['selectedVariants'] ?? []),
      imageUrl: data['image_url'] ?? '', // Ambil dari key 'image_url'
      statusProduk: (data['isAvailable'] ?? true) ? "Tersedia" : "Habis",
      sizes: data['sizes'] ?? {},
      totalStock: (data['stock'] is num) ? (data['stock'] as num).toInt() : 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': namaProduk,
      'category': kategori,
      'selectedVariants': varianRasa,
      'image_url': imageUrl,
      'isAvailable': statusProduk == "Tersedia",
      'sizes': sizes,
      'stock': totalStock,
    };
  }
}
