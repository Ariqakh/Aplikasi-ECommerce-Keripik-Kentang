import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart'
    as http; // Ditambahkan untuk mendukung HTTP POST ke backend
import 'transaction_history.dart';
import 'home_page.dart';
import 'profile_page.dart';
import '../../models/order_model.dart';

class OrderStatusPage extends StatefulWidget {
  final OrderModel order;

  const OrderStatusPage({super.key, required this.order});

  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage> {
  final Color bgLight = const Color(0xFFFDF5E6);
  final Color primaryYellow = const Color(0xFFFFB800);
  final Color textBrown = const Color(0xFF422817);
  final Color statusBrown = const Color(0xFF4C341F);
  final Color cardBg = Colors.white;
  final Color textGrey = const Color(0xFF8E8E8E);

  int _selectedIndex = 1;

  // PERBAIKAN: Fungsi proteksi data alamat agar aman dari error '[]' was called on null
  String getAlamatDisplay(dynamic alamat) {
    if (alamat == null) return "Alamat tidak tersedia";

    // Jika alamat berupa Map dari database, akses field di dalamnya secara protektif
    if (alamat is Map) {
      if (alamat.isEmpty) return "Alamat tidak tersedia";

      String detail = (alamat['detailAlamat'] ?? '').toString();
      String kelurahan = (alamat['kelurahan'] ?? '').toString();
      String wilayah = (alamat['wilayah_biteship'] ?? '').toString();
      String kota = (alamat['kota'] ?? '').toString();

      List<String> parts = [];
      if (detail.isNotEmpty) parts.add(detail);
      if (kelurahan.isNotEmpty) parts.add(kelurahan);
      if (kota.isNotEmpty) parts.add(kota);
      if (wilayah.isNotEmpty && wilayah != kota) parts.add(wilayah);

      return parts.isNotEmpty ? parts.join(", ") : "Alamat tidak lengkap";
    }

    // Jika data alamat dikirim dalam bentuk String utuh
    return alamat.toString();
  }

  double hitungBiayaAdmin(String metode, int total) {
    if (metode.isEmpty) return 0.0;
    String metodeLower = metode.toLowerCase();
    if (metodeLower.contains("qris")) {
      return total * 0.009;
    } else {
      return 4000.0;
    }
  }

  Future<void> _handleBatalPesanan() async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Batalkan Pesanan"),
            content: const Text(
                "Apakah Anda yakin ingin membatalkan pesanan keripik ini?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child:
                    const Text("Tidak", style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Ya, Batalkan",
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.id)
          .update({'statusPesanan': 'gagal'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Pesanan telah dibatalkan (Status: Gagal)")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal membatalkan pesanan: $e")),
        );
      }
    }
  }

  // FUNGSI BARU: Menangani penyelesaian pesanan oleh pembeli
  Future<void> _handlePesananSelesai() async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Selesaikan Pesanan"),
            content: const Text(
                "Apakah Anda yakin barang sudah diterima dengan baik dan ingin menyelesaikan pesanan ini?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child:
                    const Text("Batal", style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text("Ya, Selesai",
                    style: TextStyle(
                        color: statusBrown, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.id)
          .update({'statusPesanan': 'selesai'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Terima kasih! Pesanan telah selesai.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menyelesaikan pesanan: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.id)
          .snapshots(),
      builder: (context, snapshot) {
        OrderModel activeOrder = widget.order;
        String namaEkspedisi = "Ekspedisi Pilihan";
        String nomorResi = "-";
        int biayaAdmin = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          activeOrder = OrderModel.fromFirestore(snapshot.data!);
          var dataRaw = snapshot.data!.data() as Map<String, dynamic>;
          namaEkspedisi = dataRaw['ekspedisi'] ?? "Reguler";
          nomorResi = dataRaw['nomorResi'] ?? "-";

          biayaAdmin = dataRaw['biayaAdmin'] ??
              hitungBiayaAdmin(
                activeOrder.metodePembayaran,
                activeOrder.totalHargaProduk + activeOrder.ongkosKirim,
              ).toInt();
        } else {
          biayaAdmin = hitungBiayaAdmin(
            activeOrder.metodePembayaran,
            activeOrder.totalHargaProduk + activeOrder.ongkosKirim,
          ).toInt();
        }

        int totalBayarFix =
            activeOrder.totalHargaProduk + activeOrder.ongkosKirim + biayaAdmin;
        String currentStatus = activeOrder.statusPesanan.toLowerCase();

        bool isPembayaranBerhasil = currentStatus == 'pembayaran berhasil' ||
            currentStatus == 'pesanan dikonfirmasi' ||
            currentStatus == 'pesanan diproses' ||
            currentStatus == 'dikirim' ||
            currentStatus == 'selesai';

        bool isDikonfirmasi = currentStatus == 'pesanan dikonfirmasi' ||
            currentStatus == 'pesanan diproses' ||
            currentStatus == 'dikirim' ||
            currentStatus == 'selesai';

        bool isDiproses = currentStatus == 'pesanan diproses' ||
            currentStatus == 'dikirim' ||
            currentStatus == 'selesai';

        bool isDikirim =
            currentStatus == 'dikirim' || currentStatus == 'selesai';
        bool isSelesai = currentStatus == 'selesai';
        bool isDibatalkan = currentStatus == 'dibatalkan';
        bool isGagal = currentStatus == 'gagal';

        List<dynamic> itemsList = activeOrder.itemPesanan;

        return Scaffold(
          backgroundColor: bgLight,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const TransactionHistoryPage()),
                );
              },
            ),
            title: Text(
              "Status Pesanan",
              style: TextStyle(
                  color: textBrown, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("ID PESANAN",
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold)),
                            Text(activeOrder.orderId.toUpperCase(),
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: textBrown)),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          final User? user = FirebaseAuth.instance.currentUser;
                          if (user == null) return;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InternalChatRoom(
                                orderDocId: activeOrder.id,
                                orderId: activeOrder.orderId,
                                userId: user.uid,
                                userEmail: user.email ?? "Pembeli",
                                isAdmin: false,
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.message, size: 16, color: textBrown),
                        label: Text("Hubungi Penjual",
                            style: TextStyle(
                                color: textBrown,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: primaryYellow,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Status Terkini",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: textBrown)),
                      const SizedBox(height: 20),
                      if (isDibatalkan || isGagal) ...[
                        _buildTimelineItem(
                            Colors.red,
                            isGagal
                                ? "Pesanan Kedaluwarsa"
                                : "Pesanan Dibatalkan",
                            isGagal
                                ? "Pesanan dibatalkan sistem karena batas waktu pembayaran habis."
                                : "Pesanan ini telah dibatalkan oleh pembeli.",
                            isLast: true,
                            isDone: true,
                            isCurrent: true,
                            icon: Icons.error_outline),
                      ] else ...[
                        _buildTimelineItem(
                            isPembayaranBerhasil
                                ? statusBrown
                                : Colors.grey.shade300,
                            "Pembayaran Berhasil",
                            "Dana pesanan aman terverifikasi otomatis",
                            isDone: isPembayaranBerhasil,
                            isCurrent: currentStatus == 'pembayaran berhasil',
                            icon: Icons.check),
                        _buildTimelineItem(
                            isDikonfirmasi
                                ? primaryYellow
                                : Colors.grey.shade300,
                            "Pesanan Dikonfirmasi",
                            "Penjual menyetujui persiapan pesanan",
                            isDone: isDikonfirmasi,
                            isCurrent: currentStatus == 'pesanan dikonfirmasi',
                            icon: Icons.verified),
                        _buildTimelineItem(
                            isDiproses ? primaryYellow : Colors.grey.shade300,
                            "Pesanan Diproses",
                            "Produk sedang disiapkan & dikemas rapi",
                            isDone: isDiproses,
                            isCurrent: currentStatus == 'pesanan diproses',
                            icon: Icons.inventory_2_outlined),
                        _buildTimelineItem(
                            isDikirim ? primaryYellow : Colors.grey.shade300,
                            "Dikirim",
                            "Kurir sedang mengantar paket ke lokasi Anda",
                            isDone: isDikirim,
                            isCurrent: currentStatus == 'dikirim',
                            icon: Icons.local_shipping_outlined),
                        _buildTimelineItem(
                            isSelesai
                                ? const Color(0xFF00C82B)
                                : Colors.grey.shade300,
                            "Selesai",
                            "Pesanan telah sampai dengan selamat di tangan Anda!",
                            isLast: true,
                            isDone: isSelesai,
                            isCurrent: currentStatus == 'selesai',
                            icon: Icons.celebration_outlined),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt_long, color: textBrown, size: 18),
                          const SizedBox(width: 8),
                          Text("Informasi No. Resi",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textBrown)),
                        ],
                      ),
                      const Divider(height: 25, thickness: 1),
                      if (nomorResi == '-' ||
                          nomorResi.trim().isEmpty ||
                          currentStatus == 'pembayaran berhasil' ||
                          currentStatus == 'pesanan dikonfirmasi' ||
                          currentStatus == 'pesanan diproses') ...[
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.orange.shade700, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Menunggu kurir menjemput paket / Penjual belum menginput nomor resi.",
                                style: TextStyle(
                                    color: Colors.orange.shade900,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Kurir Ekspedisi: $namaEkspedisi",
                                      style: TextStyle(
                                          fontSize: 12, color: textGrey)),
                                  const SizedBox(height: 2),
                                  Text(nomorResi,
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: textBrown,
                                          letterSpacing: 0.8)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: bgLight,
                                side: BorderSide(color: textBrown, width: 1),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: nomorResi));
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            "Nomor resi berhasil disalin")));
                              },
                              child: Text("SALIN",
                                  style: TextStyle(
                                      color: textBrown,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Daftar Produk",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textBrown)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                                color: statusBrown,
                                borderRadius: BorderRadius.circular(10)),
                            child: Text("${itemsList.length} Item",
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10)),
                          )
                        ],
                      ),
                      const SizedBox(height: 15),
                      ...itemsList.map((item) {
                        String base64ImageStr = item['image_url'] ?? '';
                        Widget cardImage = base64ImageStr
                                .startsWith("data:image")
                            ? Image.memory(
                                base64Decode(base64ImageStr.split(',').last),
                                fit: BoxFit.cover)
                            : const Icon(Icons.cookie, color: Colors.grey);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: bgLight,
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15)),
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: cardImage),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['namaProduk'] ?? "Produk",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textBrown)),
                                    Text("Varian: ${item['rasa'] ?? '-'}",
                                        style: TextStyle(
                                            fontSize: 12, color: textGrey)),
                                    const SizedBox(height: 5),
                                    Text(
                                        "${item['jumlah'] ?? 1} x Rp ${NumberFormat('#,###').format(item['hargaSatuan'] ?? 0)}",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: statusBrown)),
                                  ],
                                ),
                              )
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: statusBrown, size: 18),
                          const SizedBox(width: 8),
                          Text("Alamat Pengiriman",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textBrown)),
                        ],
                      ),
                      const Divider(height: 25, thickness: 1),
                      Text(activeOrder.namaPenerima,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: textBrown)),
                      const SizedBox(height: 2),
                      Text(activeOrder.nomorTelepon,
                          style: TextStyle(color: textGrey, fontSize: 13)),
                      const SizedBox(height: 6),
                      // PERBAIKAN: Memanggil fungsi getAlamatDisplay secara aman dengan parameter alamat objek model asli
                      Text(
                        getAlamatDisplay(activeOrder.alamatLengkap),
                        style: TextStyle(
                            color: textGrey, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Rincian Pembayaran",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: textBrown)),
                      const Divider(height: 25, thickness: 1),
                      _buildPaymentRow("Metode Pembayaran",
                          activeOrder.metodePembayaran.toUpperCase()),
                      _buildPaymentRow("Total Harga Produk",
                          "Rp ${NumberFormat('#,###').format(activeOrder.totalHargaProduk)}"),
                      _buildPaymentRow("Ongkos Kirim",
                          "Rp ${NumberFormat('#,###').format(activeOrder.ongkosKirim)}"),
                      if (biayaAdmin > 0)
                        _buildPaymentRow("Biaya Admin",
                            "Rp ${NumberFormat('#,###').format(biayaAdmin)}"),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Total Pembayaran",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textBrown)),
                          Text(
                              "Rp ${NumberFormat('#,###').format(totalBayarFix)}",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                  fontSize: 16))
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // FITUR BARU: Tombol Pesanan Selesai jika statusnya sedang 'dikirim'
                if (currentStatus == 'dikirim') ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C82B),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      onPressed: _handlePesananSelesai,
                      child: const Text("Pesanan Selesai",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],

                if (currentStatus == 'pembayaran berhasil' ||
                    currentStatus == 'pesanan dikonfirmasi' ||
                    currentStatus == 'pesanan diproses')
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: _handleBatalPesanan,
                      child: const Text("Batalkan Pesanan",
                          style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildSectionContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          const BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: child,
    );
  }

  Widget _buildTimelineItem(Color color, String title, String desc,
      {bool isLast = false,
      bool isDone = false,
      bool isCurrent = false,
      required IconData icon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isCurrent
                    ? color
                    : (isDone ? color.withOpacity(0.2) : Colors.grey.shade100),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child:
                  Icon(icon, size: 16, color: isCurrent ? Colors.white : color),
            ),
            if (!isLast)
              Container(
                  width: 2,
                  height: 45,
                  color: isDone ? color : Colors.grey.shade300),
          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                      color: isCurrent ? textBrown : textBrown.withOpacity(0.7),
                      fontSize: 14)),
              const SizedBox(height: 3),
              Text(desc, style: TextStyle(color: textGrey, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textGrey, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: textBrown, fontWeight: FontWeight.w600, fontSize: 13)),
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

class InternalChatRoom extends StatefulWidget {
  final String orderDocId;
  final String orderId;
  final String userId;
  final String userEmail;
  final bool isAdmin;

  const InternalChatRoom({
    super.key,
    required this.orderDocId,
    required this.orderId,
    required this.userId,
    required this.userEmail,
    this.isAdmin = false,
  });

  @override
  State<InternalChatRoom> createState() => _InternalChatRoomState();
}

class _InternalChatRoomState extends State<InternalChatRoom> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _kirimPesan() async {
    if (_msgController.text.trim().isEmpty) return;

    String text = _msgController.text.trim();
    _msgController.clear();

    var messageData = {
      'sender': widget.isAdmin ? 'admin' : 'user',
      'text': text,
      'time': DateFormat('HH:mm').format(DateTime.now()),
    };

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderDocId)
          .update({
        'chatMessages': FieldValue.arrayUnion([messageData])
      });

      _keBarisTerbawah();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Gagal: $e")));
      }
    }
  }

  void _keBarisTerbawah() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF5E6),
      appBar: AppBar(
        title: Text(
            widget.isAdmin
                ? "Chat Pelanggan: ${widget.userEmail}"
                : "Chat Admin",
            style: const TextStyle(
                color: Color(0xFF422817),
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF422817)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .doc(widget.orderDocId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists)
                  return const Center(child: CircularProgressIndicator());

                var data = snapshot.data!.data() as Map<String, dynamic>;
                List<dynamic> messages = data['chatMessages'] ?? [];

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _keBarisTerbawah());

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var msg = messages[index];
                    bool isMe = widget.isAdmin
                        ? msg['sender'] == 'admin'
                        : msg['sender'] == 'user';

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                            color:
                                isMe ? const Color(0xFFFFB800) : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(15),
                              topRight: const Radius.circular(15),
                              bottomLeft: Radius.circular(isMe ? 15 : 0),
                              bottomRight: Radius.circular(isMe ? 0 : 15),
                            ),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2))
                            ]),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(msg['text'] ?? "",
                                style: TextStyle(
                                    color: isMe
                                        ? Colors.white
                                        : const Color(0xFF422817),
                                    fontSize: 14)),
                            const SizedBox(height: 3),
                            Text(msg['time'] ?? "",
                                style: TextStyle(
                                    color: isMe ? Colors.white70 : Colors.grey,
                                    fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: InputDecoration(
                        hintText: "Tulis pesan...",
                        hintStyle:
                            const TextStyle(color: Colors.grey, fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide:
                              const BorderSide(color: Color(0xFFFFB800)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFFFFB800),
                    child: IconButton(
                      icon:
                          const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: _kirimPesan,
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
