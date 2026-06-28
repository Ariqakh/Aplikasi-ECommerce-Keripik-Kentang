import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'cart_page.dart';
import 'order_status_page.dart';
import 'payment_page.dart';
import '../../models/order_model.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  int _selectedIndex = 1;
  String _activeFilter = "Semua";

  final Color bgLight = const Color(0xFFFDF5E6);
  final Color textBrown = const Color(0xFF422817);
  final Color primaryYellow = const Color(0xFFFFB800);
  final Color darkHeader = const Color(0xFF4C341F);
  final Color cardBg = Colors.white;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String _mapStatusToFilter(String status) {
    String s = status.toLowerCase().trim();
    if (s.contains('tunggu') ||
        s.contains('bayar') ||
        s.contains('proses') ||
        s.contains('konfirmasi') ||
        s.contains('kirim')) {
      return "Berlangsung";
    } else if (s.contains('selesai')) {
      return "Selesai";
    } else if (s.contains('batal') || s.contains('gagal')) {
      return "Dibatalkan";
    }
    return "Semua";
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64, color: textBrown.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: textBrown.withOpacity(0.6),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          "Riwayat Pesanan",
          style: TextStyle(
            color: textBrown,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Container(
            color: const Color.fromARGB(255, 108, 33, 3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SizedBox(
              height: 70,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(width: 25),
                    _buildFilterTab("Semua"),
                    _buildFilterTab("Berlangsung"),
                    _buildFilterTab("Selesai"),
                    _buildFilterTab("Dibatalkan"),
                    const SizedBox(width: 25),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: currentUser == null
                ? Center(
                    child: Text(
                      "Silakan login untuk melihat riwayat pesanan",
                      style: TextStyle(
                          color: textBrown, fontWeight: FontWeight.bold),
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('orders')
                        .where('pembeliUid',
                            isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                              "Terjadi kesalahan data: ${snapshot.error}",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 13),
                            ),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(color: textBrown),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState("Belum ada riwayat pesanan");
                      }

                      final List<OrderModel> allOrders =
                          (snapshot.data?.docs ?? []).map((doc) {
                        return OrderModel.fromFirestore(doc);
                      }).toList();

                      final List<QueryDocumentSnapshot> allDocs =
                          snapshot.data?.docs ?? [];

                      final List<Map<String, dynamic>> filteredList = [];
                      for (int i = 0; i < allOrders.length; i++) {
                        OrderModel order = allOrders[i];
                        Map<String, dynamic> rawData =
                            allDocs[i].data() as Map<String, dynamic>;

                        String dbPembeliId =
                            rawData['pembeliID'] ?? rawData['pembeliUid'] ?? '';
                        bool isMyOrder = dbPembeliId == currentUser.uid;

                        if (isMyOrder) {
                          if (_activeFilter == "Semua" ||
                              _mapStatusToFilter(order.statusPesanan) ==
                                  _activeFilter) {
                            filteredList.add({
                              'order': order,
                              'rawData': rawData,
                            });
                          }
                        }
                      }

                      filteredList.sort((a, b) {
                        OrderModel orderA = a['order'];
                        OrderModel orderB = b['order'];
                        return orderB.createdAt.compareTo(orderA.createdAt);
                      });

                      if (filteredList.isEmpty) {
                        return _buildEmptyState(
                            "Belum ada pesanan di kategori \"$_activeFilter\"");
                      }

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final OrderModel currentOrder =
                              filteredList[index]['order'];
                          final Map<String, dynamic> currentRawData =
                              filteredList[index]['rawData'];

                          return _buildOrderCard(currentOrder, currentRawData);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildFilterTab(String label) {
    bool isSelected = _activeFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = label;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryYellow : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryYellow : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textBrown,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order, Map<String, dynamic> rawData) {
    String statusS = order.statusPesanan.toLowerCase().trim();
    bool belumBayar = statusS.contains('tunggu') ||
        statusS.contains('belum') ||
        (statusS == 'menunggu pembayaran');

    var firstItem = order.itemPesanan.isNotEmpty ? order.itemPesanan[0] : null;
    String namaProduk =
        firstItem != null ? (firstItem['namaProduk'] ?? 'Produk') : 'Produk';
    String varianRasa = firstItem != null ? (firstItem['rasa'] ?? '-') : '-';
    String ukuranSize = firstItem != null ? (firstItem['ukuran'] ?? '-') : '-';
    int jumlahQty = firstItem != null ? (firstItem['jumlah'] ?? 1) : 1;
    String base64Image =
        firstItem != null ? (firstItem['image_url'] ?? '') : '';

    int sisaItemCount = order.itemPesanan.length - 1;

    Widget productImgWidget;
    try {
      if (base64Image.startsWith("data:image")) {
        final cleanBase64 = base64Image.split(',').last;
        productImgWidget =
            Image.memory(base64Decode(cleanBase64), fit: BoxFit.cover);
      } else if (base64Image.isNotEmpty) {
        productImgWidget =
            Image.memory(base64Decode(base64Image), fit: BoxFit.cover);
      } else {
        productImgWidget =
            Icon(Icons.fastfood, color: Colors.orange.shade700, size: 24);
      }
    } catch (_) {
      productImgWidget = const Icon(Icons.broken_image, color: Colors.red);
    }

    Color statusColor = Colors.orange.shade800;
    if (statusS == 'selesai') {
      statusColor = Colors.green.shade700;
    } else if (statusS == 'dibatalkan' || statusS == 'gagal') {
      statusColor = Colors.red.shade700;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('dd MMM yyyy, HH:mm').format(order.createdAt),
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  order.statusPesanan.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 0.8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: bgLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: productImgWidget,
                ),
              ),
              const SizedBox(width: 12),

              // PERBAIKAN: Dibungkus dengan Expanded agar aman dari Overflow layar kecil
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "ID: ${order.orderId}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textBrown.withOpacity(0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      namaProduk,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: textBrown,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Varian: $varianRasa | Ukuran: $ukuranSize",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$jumlahQty Barang",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: textBrown.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (sisaItemCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              "+ $sisaItemCount produk lainnya",
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Total Belanja",
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text(
                    _currencyFormat.format(order.totalBayar),
                    style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w900,
                        fontSize: 15),
                  ),
                ],
              ),
              Row(
                children: [
                  if (belumBayar) ...[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryYellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaymentPage(
                              subtotalProduk: order.totalHargaProduk,
                              totalBeratGram: order.totalBeratGram,
                              ongkosKirim: order.ongkosKirim,
                              alamatLengkap: order.alamatLengkap,
                              namaPenerima: order.namaPenerima,
                              nomorTelepon: order.nomorTelepon,
                              metodePembayaran: order.metodePembayaran,
                              detailPembayaran: order.detailPembayaran,
                              ekspedisi: rawData['ekspedisi'] ?? 'JNE',
                              orderId: order.orderId,
                            ),
                          ),
                        );
                      },
                      child: const Text("Bayar Sekarang"),
                    ),
                  ] else ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textBrown,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderStatusPage(order: order),
                          ),
                        );
                      },
                      child: const Text("Lihat Detail"),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30), topRight: Radius.circular(30)),
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
            child: Icon(icon, color: textBrown),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                  color: textBrown)),
        ],
      ),
    );
  }
}
