import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String orderId; // Kode pesanan unik
  final String pembeliUid;
  final String namaPenerima;
  final String nomorTelepon;
  // PERBAIKAN: Menggunakan dynamic agar tidak crash saat menerima tipe campuran String dari Checkout
  final Map<String, dynamic> alamatLengkap;
  final List<dynamic> itemPesanan; // Daftar keripik yang dibeli dari keranjang
  final String metodePembayaran; // "QRIS", "Transfer Bank", atau "Dana"
  final String
      detailPembayaran; // Rekening atau nama file QRIS aktif dari admin
  final int totalHargaProduk;
  final int totalBeratGram;
  final int ongkosKirim;
  final int totalBayar;
  final String
      statusPesanan; // "pembayaran berhasil", "pesanan dikonfirmasi", "pesanan diproses", "dikirim", "selesai"
  final String nomorResi;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.orderId,
    required this.pembeliUid,
    required this.namaPenerima,
    required this.nomorTelepon,
    required this.alamatLengkap,
    required this.itemPesanan,
    required this.metodePembayaran,
    required this.detailPembayaran,
    required this.totalHargaProduk,
    required this.totalBeratGram,
    required this.ongkosKirim,
    required this.totalBayar,
    required this.statusPesanan,
    required this.nomorResi,
    required this.createdAt,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // PERBAIKAN AMAN: Mengamankan konversi map alamat agar aman dari error subtype casting
    Map<String, dynamic> alamatRaw = data['alamatLengkap'] != null
        ? Map<String, dynamic>.from(data['alamatLengkap'])
        : {
            'alamat': 'Tidak ada alamat',
          }; // <-- Default object agar tidak null

    return OrderModel(
      id: doc.id,
      orderId: data['orderId'] ?? '',
      pembeliUid: data['pembeliUid'] ?? '',
      namaPenerima: data['namaPenerima'] ?? '',
      nomorTelepon: data['nomorTelepon'] ?? '',
      alamatLengkap: alamatRaw,
      itemPesanan: data['itemPesanan'] is List
          ? List<dynamic>.from(data['itemPesanan'])
          : [],
      metodePembayaran: data['metodePembayaran'] ?? '',
      detailPembayaran: data['detailPembayaran'] ?? '',
      totalHargaProduk: data['totalHargaProduk'] ?? 0,
      totalBeratGram: data['totalBeratGram'] ?? 0,
      ongkosKirim: data['ongkosKirim'] ?? 0,
      totalBayar: data['totalBayar'] ?? 0,
      statusPesanan: data['statusPesanan'] ?? 'Menunggu Pembayaran',
      nomorResi: data['nomorResi'] ?? '-',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'pembeliUid': pembeliUid,
      'namaPenerima': namaPenerima,
      'nomorTelepon': nomorTelepon,
      'alamatLengkap': alamatLengkap,
      'itemPesanan': itemPesanan,
      'metodePembayaran': metodePembayaran,
      'detailPembayaran': detailPembayaran,
      'totalHargaProduk': totalHargaProduk,
      'totalBeratGram': totalBeratGram,
      'ongkosKirim': ongkosKirim,
      'totalBayar': totalBayar,
      'statusPesanan': statusPesanan,
      'nomorResi': nomorResi,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
