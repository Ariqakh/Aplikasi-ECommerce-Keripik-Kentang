import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =========================================================================
  // ALUR PEMBELI (FITUR UTAMA)
  // =========================================================================

  Stream<List<ProductModel>> getProductsStream() {
    return _db.collection('products').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> addToCart({
    required String uid,
    required String productId,
    required String namaProduk,
    required String rasa,
    required String ukuran,
    required int hargaSatuan,
    required int jumlah,
    required int beratGram,
  }) async {
    await _db.collection('users').doc(uid).collection('cart').add({
      'productId': productId,
      'namaProduk': namaProduk,
      'rasa': rasa,
      'ukuran': ukuran,
      'hargaSatuan': hargaSatuan,
      'jumlah': jumlah,
      'beratGram': beratGram,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getCartStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('cart')
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Future<void> updateCartItemQuantity(
      String uid, String cartItemId, int jumlahBaru) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('cart')
        .doc(cartItemId)
        .update({
      'jumlah': jumlahBaru,
    });
  }

  Future<void> deleteCartItem(String uid, String cartItemId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('cart')
        .doc(cartItemId)
        .delete();
  }

  int hitungOngkosKirim(
      {required int totalBeratGram, required String kotaKabupaten}) {
    double beratKg = totalBeratGram / 1000;
    if (beratKg < 1.0) beratKg = 1.0;

    int tarifPerKg = 12000;

    String lokasiPenerima = kotaKabupaten.toLowerCase();
    if (lokasiPenerima.contains('tanjung pinang') ||
        lokasiPenerima.contains('tanjungpinang')) {
      tarifPerKg = 7000;
    } else if (lokasiPenerima.contains('batam')) {
      tarifPerKg = 15000;
    } else if (lokasiPenerima.contains('bintan')) {
      tarifPerKg = 10000;
    } else if (lokasiPenerima.contains('karimun')) {
      tarifPerKg = 22000;
    }

    return (beratKg * tarifPerKg).round();
  }

  Future<void> checkoutOrder(OrderModel order, String uid) async {
    await _db.collection('orders').doc(order.orderId).set(order.toMap());

    var cartSnapshot =
        await _db.collection('users').doc(uid).collection('cart').get();
    for (var doc in cartSnapshot.docs) {
      await doc.reference.delete();
    }
  }

  Stream<List<OrderModel>> getPembeliOrdersStream(String uid) {
    return _db
        .collection('orders')
        .where('pembeliUid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> updateProfileName(String uid, String namaBaru) async {
    await _db.collection('users').doc(uid).update({
      'nama': namaBaru,
    });
  }

  // =========================================================================
  // ALUR ADMIN (FITUR UTAMA)
  // =========================================================================

  Stream<List<OrderModel>> getAllOrdersForAdminStream() {
    return _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> addProduct(ProductModel product) async {
    await _db.collection('products').add(product.toMap());
  }

  Future<void> updateProduct(String productId, ProductModel product) async {
    await _db.collection('products').doc(productId).update(product.toMap());
  }

  Future<void> deleteProduct(String productId) async {
    await _db.collection('products').doc(productId).delete();
  }

  Future<void> updateOrderStatus(String orderId, String statusBaru,
      {String nomorResi = "-"}) async {
    await _db.collection('orders').doc(orderId).update({
      'statusPesanan': statusBaru,
      'nomorResi': nomorResi,
    });
  }

  // PERBAIKAN: Stream baru untuk struktur pembayaran yang sudah dipisah
  Stream<List<Map<String, dynamic>>> getPaymentSettingsStream() {
    return _db.collection('payment_settings').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'type': doc['type'] ?? '',
          'bankName': doc['bankName'] ?? '',
          'accountNumber': doc['accountNumber'] ?? '',
          'accountName': doc['accountName'] ?? '',
        };
      }).toList();
    });
  }

  // PERBAIKAN: Fungsi simpan metode pembayaran baru dengan struktur terpisah
  Future<void> addPaymentMethod({
    required String type,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    await _db.collection('payment_settings').add({
      'type': type,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountName': accountName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePaymentMethod(String methodId) async {
    await _db.collection('payment_settings').doc(methodId).delete();
  }
}
