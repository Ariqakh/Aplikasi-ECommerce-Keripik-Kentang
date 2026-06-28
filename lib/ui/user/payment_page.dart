import 'dart:convert';
import 'dart:async'; // Diperlukan untuk sistem Timer Hitung Mundur
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Diperlukan untuk fitur Clipboard (Salin Teks)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../models/order_model.dart';
import 'order_status_page.dart';

class PaymentPage extends StatefulWidget {
  final int subtotalProduk;
  final int totalBeratGram;
  final int ongkosKirim;
  final Map<String, dynamic> alamatLengkap;
  final String namaPenerima;
  final String nomorTelepon;
  final String metodePembayaran;
  final String detailPembayaran;
  final String ekspedisi;
  final String?
      orderId; // PARAMETER BARU: Menampung ID dari transaksi lama jika ditekan lewat riwayat

  const PaymentPage({
    super.key,
    required this.subtotalProduk,
    required this.totalBeratGram,
    required this.ongkosKirim,
    required this.alamatLengkap,
    required this.namaPenerima,
    required this.nomorTelepon,
    required this.metodePembayaran,
    required this.detailPembayaran,
    required this.ekspedisi,
    this.orderId, // Opsional, jika dari checkout kosong, jika dari riwayat terisi
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  final Color primaryYellow = const Color(0xFFFFB800);
  final Color bgLight = const Color(0xFFFDF5E6);
  final Color darkBrown = const Color(0xFF422817);

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  bool _isLoading = true;
  bool _isQris = false;
  String _vaNumber = "Membuat Kode Bayar...";
  String _qrisQrUrl = "";
  String _generatedOrderId = "";
  String _errorMessage = "";

  // Variabel untuk sistem Timer 24 Jam
  Timer? _countdownTimer;
  Duration _remainingTime = const Duration(hours: 24);
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();

    // Jika dikirim dari riwayat pesanan, gunakan orderId lama. Jika dari checkout, buat ID baru.
    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      _generatedOrderId = widget.orderId!;
    } else {
      _generatedOrderId =
          "KK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inisialisasiWaktuDanPembayaran();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel(); // Mencegah memory leak saat halaman ditutup
    super.dispose();
  }

  // Mengatur kalkulasi sisa waktu secara dinamis berdasarkan data Firestore nyata
  Future<void> _inisialisasiWaktuDanPembayaran() async {
    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      try {
        // Ambil data pesanan lama dari Firestore untuk mengecek createdAt asli
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(_generatedOrderId)
            .get();

        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          // Jika di database statusnya sudah terlanjur batal/selesai, kunci ke expired
          String dbStatus =
              (data['statusPesanan'] ?? '').toString().toLowerCase();
          if (dbStatus == 'dibatalkan') {
            setState(() {
              _isExpired = true;
              _remainingTime = Duration.zero;
              _isLoading = false;
              _errorMessage =
                  "Transaksi ini telah dibatalkan atau kedaluwarsa.";
            });
            return;
          }

          Timestamp timestamp = data['createdAt'] as Timestamp;
          DateTime waktuDibuat = timestamp.toDate();
          DateTime waktuMaksimal = waktuDibuat.add(const Duration(hours: 24));
          DateTime waktuSekarang = DateTime.now();

          if (waktuSekarang.isAfter(waktuMaksimal)) {
            _isExpired = true;
            _remainingTime = Duration.zero;
            _tanganiPesananKadaluarsa();
          } else {
            // Hitung sisa selisih waktu berjalan yang tersisa sekarang
            _remainingTime = waktuMaksimal.difference(waktuSekarang);
          }
        }
      } catch (e) {
        print("Gagal sinkronisasi waktu pesanan lama: $e");
      }
    }

    // Jalankan timer visual hitung mundur
    _startTimer();
    // Panggil fungsi transaksi Midtrans Gateway
    _inisialisasiPembayaranMurni();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    if (_isExpired) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingTime.inSeconds > 0) {
            _remainingTime = _remainingTime - const Duration(seconds: 1);
          } else {
            _countdownTimer?.cancel();
            _isExpired = true;
            _tanganiPesananKadaluarsa();
          }
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours : $minutes : $seconds";
  }

  // FUNGSI PERBAIKAN: Membatalkan pesanan DAN mengembalikan stok
  Future<void> _tanganiPesananKadaluarsa() async {
    try {
      final firestore = FirebaseFirestore.instance;
      DocumentSnapshot orderDoc =
          await firestore.collection('orders').doc(_generatedOrderId).get();

      if (orderDoc.exists) {
        Map<String, dynamic> data = orderDoc.data() as Map<String, dynamic>;

        // Hanya proses jika belum dibatalkan untuk menghindari duplikasi rollback
        if (data['statusPesanan'] != 'dibatalkan') {
          List<dynamic> items = data['itemPesanan'] ?? [];
          final batch = firestore.batch();

          // Loop untuk mengembalikan stok setiap produk
          for (var item in items) {
            String productId = item['productId'];
            int jumlah = item['jumlah'] ?? 1;
            DocumentReference productRef =
                firestore.collection('products').doc(productId);
            batch.update(productRef, {'stok': FieldValue.increment(jumlah)});
          }

          // Update status pesanan
          batch.update(orderDoc.reference, {'statusPesanan': 'dibatalkan'});
          await batch.commit();
        }
      }
    } catch (e) {
      print("Gagal otomatis membatalkan transaksi dan mengembalikan stok: $e");
    }
  }

  int _hitungTotalBersih() {
    int basis = widget.subtotalProduk + widget.ongkosKirim;
    String metodeLower = widget.metodePembayaran.toLowerCase();

    if (metodeLower.contains("bank") || metodeLower.contains("seabank")) {
      return basis + 4000;
    } else if (metodeLower.contains("qris")) {
      return (basis + (basis * 0.009)).toInt();
    }
    return basis;
  }

  Future<void> _inisialisasiPembayaranMurni() async {
    int totalTagihanNet = _hitungTotalBersih();

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = "";
      });
    }

    String namaBankDariAdmin = widget.metodePembayaran.toLowerCase();
    String bankClean = "bca";

    if (namaBankDariAdmin.contains("qris")) {
      bankClean = "qris";
      _isQris = true;
    } else if (namaBankDariAdmin.contains("seabank")) {
      bankClean = "seabank";
    } else if (namaBankDariAdmin.contains("bca")) {
      bankClean = "bca";
    } else if (namaBankDariAdmin.contains("bni")) {
      bankClean = "bni";
    } else if (namaBankDariAdmin.contains("bri")) {
      bankClean = "bri";
    } else if (namaBankDariAdmin.contains("mandiri")) {
      bankClean = "mandiri";
    } else if (namaBankDariAdmin.contains("permata")) {
      bankClean = "permata";
    }

    // JIKA AKSES DARI CHECKOUT (orderId == null), SIMPAN PESANAN BARU KE FIRESTORE
    if (widget.orderId == null || widget.orderId!.isEmpty) {
      await _buatPesananKeFirestore(totalTagihanNet);
    } else {
      // JIKA AKSES DARI RIWAYAT, CEK APAKAH SUDAH ADA KODE BAYAR DI DATABASE AGAR TIDAK HIT API ULANG
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(_generatedOrderId)
            .get();
        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          if (_isQris && (data['qris_url'] ?? '').toString().isNotEmpty) {
            if (mounted) {
              setState(() {
                _qrisQrUrl = data['qris_url'];
                _isLoading = false;
              });
            }
            return; // Berhenti di sini, gunakan kode QRIS lama
          } else if (!_isQris &&
              (data['virtual_account'] ?? '').toString().isNotEmpty &&
              data['virtual_account'] != 'Memproses...') {
            if (mounted) {
              setState(() {
                _vaNumber = data['virtual_account'];
                _isLoading = false;
              });
            }
            return; // Berhenti di sini, gunakan kode VA lama
          }
        }
      } catch (e) {
        print("Gagal memuat token lama database: $e");
      }
    }

    // JIKA BELUM ADA TOKEN/KODE TERSEDIA, BARU HIT API GATEWAY MIDTRANS
    final url = Uri.parse(
      'https://api-midtras-production.up.railway.app/create-transaction',
    );

    try {
      // Mengambil item dari Firestore untuk dikirim ke dashboard
      final cartSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('cart')
          .get();

      List<Map<String, dynamic>> itemsFormatted = cartSnapshot.docs.map((doc) {
        final d = doc.data();
        return {
          "id": d['productId'] ?? "unknown",
          "price": d['hargaSatuan'] ?? 0,
          "quantity": d['jumlah'] ?? 1,
          "name": d['namaProduk'] ?? "Produk"
        };
      }).toList();

      // Debugging untuk memastikan data tidak null
      print("Nilai Telepon: ${widget.nomorTelepon}");
      print("Nilai Alamat: ${widget.alamatLengkap}");

      final Map<String, dynamic> requestBody = {
        "orderId": _generatedOrderId,
        "amount": totalTagihanNet,
        "firstName": widget.namaPenerima,
        "email": currentUser?.email ?? "user@email.com",
        "bank": bankClean,
        "phone": widget.nomorTelepon ?? "08000000000",
        "address": widget.alamatLengkap
            .toString(), // Menggunakan toString() untuk keamanan
        "items": itemsFormatted
      };

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (_isQris) {
          if (decoded['actions'] != null) {
            String qrUrl = "";
            for (var action in decoded['actions']) {
              if (action['name'] == 'generate-qr-code') {
                qrUrl = action['url'] ?? "";
                break;
              }
            }

            if (qrUrl.isNotEmpty) {
              if (mounted) {
                setState(() {
                  _qrisQrUrl = qrUrl;
                  _isLoading = false;
                });
              }
              await FirebaseFirestore.instance
                  .collection('orders')
                  .doc(_generatedOrderId)
                  .update({'qris_url': qrUrl});
            } else {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = "Gagal memuat QR Code QRIS dari Midtrans.";
                });
              }
            }
          } else {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = "Respon QRIS Midtrans tidak valid.";
              });
            }
          }
        } else {
          String updateVa = "-";
          if (decoded['va_numbers'] != null &&
              decoded['va_numbers'].isNotEmpty) {
            updateVa = decoded['va_numbers'][0]['va_number'] ?? "-";
          } else if (decoded['bill_key'] != null) {
            updateVa =
                "Kode Perusahaan: ${decoded['biller_code']}\nKode Bayar: ${decoded['bill_key']}";
          } else if (decoded['permata_va_number'] != null) {
            updateVa = decoded['permata_va_number'] ?? "-";
          } else {
            if (mounted) {
              setState(() {
                _vaNumber = "Gagal mengambil Virtual Account";
                _isLoading = false;
                _errorMessage =
                    "Metode bank transfer tidak merespon dengan benar.";
              });
            }
            return;
          }

          if (mounted) {
            setState(() {
              _vaNumber = updateVa;
              _isLoading = false;
            });
          }

          await FirebaseFirestore.instance
              .collection('orders')
              .doc(_generatedOrderId)
              .update({
            'virtual_account': updateVa,
            'detailPembayaran': "Nomor VA: $updateVa",
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                "Gagal terhubung ke Server Gateway (Status ${response.statusCode}). Pesanan Anda tetap tersimpan di riwayat.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "Terjadi gangguan jaringan: $e. Pesanan Anda tetap tersimpan.";
        });
      }
    }
  }

  Future<void> _buatPesananKeFirestore(int totalBayar) async {
    try {
      final cartSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('cart')
          .get();

      List<Map<String, dynamic>> items =
          cartSnapshot.docs.map((d) => d.data()).toList();
      if (items.isEmpty) return;

      OrderModel newOrder = OrderModel(
        id: _generatedOrderId,
        orderId: _generatedOrderId,
        pembeliUid: currentUser!.uid,
        namaPenerima: widget.namaPenerima,
        nomorTelepon: widget.nomorTelepon,
        alamatLengkap: widget.alamatLengkap,
        itemPesanan: items,
        metodePembayaran: widget.metodePembayaran,
        detailPembayaran: _isQris
            ? "Pembayaran via QRIS (Memproses)"
            : "Nomor VA: Memproses Kode...",
        totalHargaProduk: widget.subtotalProduk,
        totalBeratGram: widget.totalBeratGram,
        ongkosKirim: widget.ongkosKirim,
        totalBayar: totalBayar,
        statusPesanan: 'menunggu pembayaran',
        nomorResi: '-',
        createdAt: DateTime.now(),
      );

      Map<String, dynamic> orderData = newOrder.toMap();
      orderData['ekspedisi'] = widget.ekspedisi;

      orderData['qris_url'] = '';
      orderData['virtual_account'] = 'Memproses...';

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(_generatedOrderId)
          .set(orderData);

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in cartSnapshot.docs) {
        final d = doc.data();
        String productId = d['productId'] ?? '';
        int jumlahBeli = d['jumlah'] ?? 1;

        if (productId.isNotEmpty) {
          final productRef =
              FirebaseFirestore.instance.collection('products').doc(productId);
          batch
              .update(productRef, {'stock': FieldValue.increment(-jumlahBeli)});
        }
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print("Gagal backup data pesanan ke Firestore: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalTagihanBersih = _hitungTotalBersih();

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text(
          "Pembayaran",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: darkBrown,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            // 1. Ambil data order dari Firestore agar bisa dikirim ke halaman status
            DocumentSnapshot doc = await FirebaseFirestore.instance
                .collection('orders')
                .doc(_generatedOrderId)
                .get();

            if (doc.exists && mounted) {
              // 2. Ubah data Firestore menjadi objek OrderModel
              OrderModel order = OrderModel.fromFirestore(doc);

              // 3. Navigasi ke halaman status dengan membawa data order tersebut
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => OrderStatusPage(order: order)));
            } else {
              // Jika data tidak ditemukan, kembali ke halaman sebelumnya secara normal
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // =========================================================================
            // COMPONENT 1: TIMER HITUNG MUNDUR 24 JAM (SINKRON DATA ASLI)
            // =========================================================================
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
              decoration: BoxDecoration(
                color: _isExpired ? Colors.red.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color:
                      _isExpired ? Colors.red.shade200 : Colors.orange.shade200,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: _isExpired ? Colors.red : Colors.orange.shade800,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isExpired
                            ? "Batas Waktu Habis"
                            : "Sisa Waktu Pembayaran",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isExpired
                              ? Colors.red.shade900
                              : Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _isExpired ? "BATAL" : _formatDuration(_remainingTime),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _isExpired
                          ? Colors.red.shade700
                          : Colors.orange.shade900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    _isQris ? "SCAN KODE QRIS" : "TRANSFER VIRTUAL ACCOUNT",
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.metodePembayaran.toUpperCase(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: darkBrown,
                    ),
                  ),
                  const Divider(height: 40, thickness: 1),
                  _isLoading
                      ? const SizedBox(
                          height: 30,
                          width: 30,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.amber,
                          ),
                        )
                      : _errorMessage.isNotEmpty
                          ? Column(
                              children: [
                                Text(
                                  _errorMessage,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  "Silakan cek menu 'Riwayat Pesanan' untuk memantau status pembayaran.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                )
                              ],
                            )
                          : _isQris
                              ? Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: Image.network(
                                        _qrisQrUrl,
                                        width: 230,
                                        height: 230,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                    Text(
                                      "Silakan screenshot QR Code di atas.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: bgLight,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: primaryYellow.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: SelectableText(
                                          _vaNumber,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 18,
                                            letterSpacing: 1.5,
                                            fontWeight: FontWeight.bold,
                                            color: darkBrown,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.copy,
                                          size: 20,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () {
                                          String cleanNumber =
                                              _vaNumber.replaceAll(
                                            RegExp(r'[^0-9]'),
                                            '',
                                          );
                                          Clipboard.setData(
                                            ClipboardData(text: cleanNumber),
                                          ).then((_) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "Nomor Virtual Account berhasil disalin!",
                                                ),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                  const Divider(height: 40, thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Total yang Harus Dibayar",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: darkBrown,
                          ),
                        ),
                      ),
                      Text(
                        _currencyFormat.format(totalTagihanBersih),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // =========================================================================
            // COMPONENT 2: PANDUAN PETUNJUK CARA TRANSFER DINAMIS
            // =========================================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Cara Melakukan Pembayaran",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: darkBrown,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _isQris
                      ? _buildPetunjukList([
                          "Buka aplikasi e-wallet Anda (GoPay, OVO, Dana, LinkAja, ShopeePay) atau Mobile Banking.",
                          "Pilih fitur pembaca QR Code / Scan / Bayar pada aplikasi tersebut.",
                          "Arahkan kamera ke QR Code atau upload hasil screenshot QR Code yang ada di halaman ini.",
                          "Periksa apakah nominal yang muncul sudah sesuai dengan total tagihan toko.",
                          "Masukkan PIN keamanan Anda untuk menyelesaikan proses pembayaran.",
                        ])
                      : _buildPetunjukList([
                          "Salin nomor Virtual Account (VA) yang tertera di atas dengan menekan tombol ikon copy.",
                          "Buka aplikasi Mobile Banking atau pergi ke ATM Bank pilihan Anda.",
                          "Pilih menu 'Transfer', kemudian cari dan klik pilihan 'Virtual Account' atau 'Briva/Gopay/E-Channel' sesuai bank.",
                          "Tempel (paste) atau masukkan nomor Virtual Account yang telah disalin tadi.",
                          "Pastikan jumlah nominal transfer tertera sama persis dengan total tagihan, lalu konfirmasi dengan PIN Anda.",
                        ]),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPetunjukList(List<String> langkah) {
    return Column(
      children: langkah.asMap().entries.map((item) {
        int index = item.key + 1;
        String teks = item.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: primaryYellow.withOpacity(0.2),
                child: Text(
                  "$index",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: darkBrown,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  teks,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
