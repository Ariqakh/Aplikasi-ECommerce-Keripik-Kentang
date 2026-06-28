import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import 'payment_page.dart';
import 'transaction_history.dart';
import 'profile_page.dart';
import 'home_page.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // =========================================================================
  // ⚡ KUNCI API BITESHIP LIVE (Hanya digunakan untuk autocomplete cari wilayah)
  // =========================================================================
  final String _biteshipApiKey =
      "biteship_live.eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiQVBLLWtlcmlwaWsta2VudGFuZyIsInVzZXJJZCI6IjZhMWZkZDRlM2M2YjFlZGM3MzQ0MzUxZCIsImlhdCI6MTc4MTAyMjc0MX0.b-nIgADLFBdKzfQQ_JHauB7v6r5S65MV_1bxwkpD11Y";

  // Daftar Metode Pembayaran Resmi Midtrans
  final List<Map<String, String>> _metodePembayaranList = [
    {"nama": "BCA Virtual Account", "kode": "bca"},
    {"nama": "BNI Virtual Account", "kode": "bni"},
    {"nama": "BRI Virtual Account", "kode": "bri"},
    {"nama": "Mandiri Bill Payment", "kode": "mandiri"},
    {"nama": "QRIS (Gopay/Shopee/OVO)", "kode": "qris"},
  ];

  // State Pilihan Pembayaran & Ekspedisi
  String? _selectedPayment;
  String? _selectedPaymentDetail;
  String? _selectedCourier;
  bool _isLoading = false;
  bool _isLoadingOngkir = false;

  // State Tampungan Data Wilayah/Area dari Biteship
  List<dynamic> _searchResults = [];
  String? _selectedAreaId;
  String? _selectedWilayahNama;
  String _autoPostalCode = "29124";

  // Nilai Ongkir Real-time & Wadah Tampungan Estimasi Hari (ETA)
  int _ongkirValue = 0;
  String _jneEta = "Pilih wilayah terlebih dahulu";
  String _jntEta = "Pilih wilayah terlebih dahulu";

  // State Pelacak Ketersediaan Rute Kurir Resmi
  bool _jneTersedia = true;
  bool _jntTersedia = true;

  // Controllers untuk Alamat Pengiriman
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _teleponController = TextEditingController();
  final TextEditingController _cariWilayahController = TextEditingController();
  final TextEditingController _kelurahanController = TextEditingController();
  final TextEditingController _detailAlamatController = TextEditingController();

  // Palet Warna Sesuai Desain
  final Color bgCream = const Color(0xFFFDF7E9);
  final Color textBrown = const Color(0xFF422817);
  final Color primaryYellow = const Color(0xFFFFB800);
  final Color inputBg = const Color(0xFFF9F1E7);
  final Color bgLight = const Color(0xFFFDF5E6);

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _namaController.text = "";
    _teleponController.text = "";
  }

  @override
  void dispose() {
    _namaController.dispose();
    _teleponController.dispose();
    _cariWilayahController.dispose();
    _kelurahanController.dispose();
    _detailAlamatController.dispose();
    super.dispose();
  }

  // Logika Biaya Admin Midtrans
  double hitungBiayaAdmin(String metode, int total) {
    if (metode.isEmpty) return 0.0;
    String metodeLower = metode.toLowerCase();
    if (metodeLower.contains("qris")) {
      return total * 0.009;
    } else {
      return 4000.0;
    }
  }

  // =========================================================================
  // 🗺️ HTTP GET: MENCARI DATA WILAYAH DI BITESHIP
  // =========================================================================
  Future<void> _searchWilayahBiteship(String query) async {
    if (query.trim().length < 3) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    final String encodedQuery = Uri.encodeComponent(query.trim());
    final url = Uri.parse(
        'https://api.biteship.com/v1/maps/areas?countries=ID&input=$encodedQuery');

    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $_biteshipApiKey",
          "Content-Type": "application/json"
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _searchResults = data['areas'] ?? [];
        });
      }
    } catch (e) {
      print("Error ambil data wilayah Biteship: $e");
    }
  }

  // =========================================================================
  // 📦 TARIF ONGKIR MANUAL LENGKAP - JNE & JNT (DENGAN PENAMBAHAN +50G LUAR KEPRI)
  // =========================================================================
  Future<void> _hitungOngkirBiteship(
      String courierName, int totalBeratGram) async {
    if (_selectedWilayahNama == null) return;

    setState(() {
      _selectedCourier = courierName;
      _isLoadingOngkir = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    String wilayah = _selectedWilayahNama!.toLowerCase();

    // Deteksi wilayah untuk menentukan berat kargo akhir
    int beratDihitung = totalBeratGram;
    bool isLuarKepri = true;

    // Cek jika wilayah pengiriman termasuk dalam area Kepulauan Riau
    if (wilayah.contains("tanjungpinang") ||
        wilayah.contains("tanjung pinang") ||
        wilayah.contains("batam") ||
        wilayah.contains("bintan") ||
        wilayah.contains("kijang") ||
        wilayah.contains("karimun") ||
        wilayah.contains("lingga") ||
        wilayah.contains("natuna") ||
        wilayah.contains("anambas") ||
        wilayah.contains("kepulauan riau")) {
      isLuarKepri = false;
    }

    // Jika pesanan ditujukan ke luar Kepulauan Riau, tambahkan beban packing 50 gram
    if (isLuarKepri) {
      beratDihitung += 50;
    }

    int jneBase = 25000;
    int jntBase = 24000;

    String jneDay = "2-4 hari";
    String jntDay = "2-3 hari";

    if (wilayah.contains("tanjungpinang") ||
        wilayah.contains("tanjung pinang")) {
      jneBase = 11000;
      jntBase = 10000;
      jneDay = "1-2 hari";
      jntDay = "1-2 hari";
    } else if (wilayah.contains("batam") ||
        wilayah.contains("bintan") ||
        wilayah.contains("karimun") ||
        wilayah.contains("lingga") ||
        wilayah.contains("natuna") ||
        wilayah.contains("anambas") ||
        wilayah.contains("kepulauan riau")) {
      jneBase = 16000;
      jntBase = 15000;
      jneDay = "2-3 hari";
      jntDay = "1-3 hari";
    } else if (wilayah.contains("riau") ||
        wilayah.contains("pekanbaru") ||
        wilayah.contains("padang") ||
        wilayah.contains("sumatera barat") ||
        wilayah.contains("jambi") ||
        wilayah.contains("medan") ||
        wilayah.contains("sumatera utara") ||
        wilayah.contains("aceh") ||
        wilayah.contains("bengkulu")) {
      jneBase = 24000;
      jntBase = 23000;
      jneDay = "3-4 hari";
      jntDay = "2-4 hari";
    } else if (wilayah.contains("palembang") ||
        wilayah.contains("sumatera selatan") ||
        wilayah.contains("lampung") ||
        wilayah.contains("bangka") ||
        wilayah.contains("belitung")) {
      jneBase = 23000;
      jntBase = 22000;
      jneDay = "3-4 hari";
      jntDay = "2-4 hari";
    } else if (wilayah.contains("jakarta") ||
        wilayah.contains("bogor") ||
        wilayah.contains("depok") ||
        wilayah.contains("tangerang") ||
        wilayah.contains("bekasi") ||
        wilayah.contains("banten") ||
        wilayah.contains("jawa barat") ||
        wilayah.contains("bandung")) {
      jneBase = 22000;
      jntBase = 20000;
      jneDay = "2-3 hari";
      jntDay = "2-3 hari";
    } else if (wilayah.contains("jawa tengah") ||
        wilayah.contains("yogyakarta") ||
        wilayah.contains("semarang") ||
        wilayah.contains("solo") ||
        wilayah.contains("surakarta") ||
        wilayah.contains("diy")) {
      jneBase = 26000;
      jntBase = 24000;
      jneDay = "3-4 hari";
      jntDay = "3-4 hari";
    } else if (wilayah.contains("jawa timur") ||
        wilayah.contains("surabaya") ||
        wilayah.contains("malang") ||
        wilayah.contains("madura")) {
      jneBase = 27000;
      jntBase = 25000;
      jneDay = "3-4 hari";
      jntDay = "3-4 hari";
    } else if (wilayah.contains("bali") ||
        wilayah.contains("denpasar") ||
        wilayah.contains("nusa tenggara") ||
        wilayah.contains("ntb") ||
        wilayah.contains("ntt") ||
        wilayah.contains("lombok")) {
      jneBase = 35000;
      jntBase = 34000;
      jneDay = "4-5 hari";
      jntDay = "3-5 hari";
    } else if (wilayah.contains("kalimantan") ||
        wilayah.contains("pontianak") ||
        wilayah.contains("banjarmasin") ||
        wilayah.contains("samarinda") ||
        wilayah.contains("balikpapan")) {
      jneBase = 34000;
      jntBase = 33000;
      jneDay = "3-5 hari";
      jntDay = "3-4 hari";
    } else if (wilayah.contains("sulawesi") ||
        wilayah.contains("makassar") ||
        wilayah.contains("manado") ||
        wilayah.contains("palu") ||
        wilayah.contains("kendari")) {
      jneBase = 38000;
      jntBase = 36000;
      jneDay = "4-6 hari";
      jntDay = "3-5 hari";
    } else if (wilayah.contains("maluku") ||
        wilayah.contains("papua") ||
        wilayah.contains("jayapura") ||
        wilayah.contains("ambon") ||
        wilayah.contains("ternate") ||
        wilayah.contains("sorong")) {
      jneBase = 55000;
      jntBase = 52000;
      jneDay = "5-8 hari";
      jntDay = "4-7 hari";
    }

    double beratKg = beratDihitung / 1000.0;
    if (beratKg < 1.0) beratKg = 1.0;
    int faktorBerat = beratKg.ceil();

    setState(() {
      _jneEta = "Estimasi: $jneDay";
      _jntEta = "Estimasi: $jntDay";

      _jneTersedia = true;
      _jntTersedia = true;

      if (courierName == "JNE") {
        _ongkirValue = jneBase * faktorBerat;
      } else if (courierName == "J&T (JNT)") {
        _ongkirValue = jntBase * faktorBerat;
      }

      _isLoadingOngkir = false;
    });
  }

  void _navigateToPayment(int subtotal, int totalBerat, int ongkir) {
    if (_namaController.text.isEmpty ||
        _teleponController.text.isEmpty ||
        _selectedAreaId == null ||
        _detailAlamatController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Mohon lengkapi alamat dan wilayah pengiriman Anda!")),
      );
      return;
    }

    if (_selectedCourier == null || _ongkirValue == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "Silakan pilih ekspedisi pengiriman resmi yang tersedia!")),
      );
      return;
    }

    if (_selectedPayment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Silakan pilih salah satu metode pembayaran!")),
      );
      return;
    }

    // Hitung berat akhir yang akan dikirim ke halaman pembayaran (termasuk tambahan packing jika luar kepri)
    String wilayah = (_selectedWilayahNama ?? "").toLowerCase();
    int beratFinalKargo = totalBerat;
    if (!wilayah.contains("tanjungpinang") &&
        !wilayah.contains("tanjung pinang") &&
        !wilayah.contains("batam") &&
        !wilayah.contains("bintan") &&
        !wilayah.contains("kijang") &&
        !wilayah.contains("karimun") &&
        !wilayah.contains("lingga") &&
        !wilayah.contains("natuna") &&
        !wilayah.contains("anambas") &&
        !wilayah.contains("kepulauan riau")) {
      beratFinalKargo += 50;
    }

    Map<String, dynamic> alamatLengkapMap = {
      'wilayah_biteship': _selectedWilayahNama,
      'kelurahan': _kelurahanController.text.trim(),
      'detailAlamat': _detailAlamatController.text.trim(),
      'ekspedisiPilihan': _selectedCourier,
    };

    setState(() {
      _isLoading = true;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          subtotalProduk: subtotal,
          totalBeratGram: beratFinalKargo,
          ongkosKirim: ongkir,
          alamatLengkap: alamatLengkapMap,
          namaPenerima: _namaController.text.trim(),
          nomorTelepon: _teleponController.text.trim(),
          metodePembayaran: _selectedPayment!,
          detailPembayaran:
              _selectedPaymentDetail ?? "Pembayaran Gateway Midtrans",
          ekspedisi: _selectedCourier!,
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textBrown),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Pembayaran",
            style: TextStyle(
                color: textBrown, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: textBrown))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser?.uid)
                  .collection('cart')
                  .snapshots(),
              builder: (context, snapshot) {
                int subtotal = 0;
                int totalBeratGram = 0;
                List<Map<String, dynamic>> checkoutItems = [];

                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final int hargaSatuan = data['hargaSatuan'] ?? 0;
                    final int jumlah = data['jumlah'] ?? 1;
                    final int beratGram = data['beratGram'] ?? 100;

                    subtotal += (hargaSatuan * jumlah);
                    totalBeratGram += (beratGram * jumlah);

                    checkoutItems.add({
                      'productId': data['productId'] ?? '',
                      'namaProduk': data['namaProduk'] ?? '',
                      'rasa': data['rasa'] ?? '',
                      'ukuran': data['ukuran'] ?? '100G',
                      'jumlah': jumlah,
                      'hargaSatuan': hargaSatuan,
                      'beratGram': beratGram,
                      'image_url': data['image_url'] ?? ''
                    });
                  }
                }

                // Kalkulasi penambahan beban packing visual di ringkasan harga
                String wilayah = (_selectedWilayahNama ?? "").toLowerCase();
                int beratTampilRingkasan = totalBeratGram;
                if (_selectedWilayahNama != null &&
                    !wilayah.contains("tanjungpinang") &&
                    !wilayah.contains("tanjung pinang") &&
                    !wilayah.contains("batam") &&
                    !wilayah.contains("bintan") &&
                    !wilayah.contains("kijang") &&
                    !wilayah.contains("karimun") &&
                    !wilayah.contains("lingga") &&
                    !wilayah.contains("natuna") &&
                    !wilayah.contains("anambas") &&
                    !wilayah.contains("kepulauan riau")) {
                  beratTampilRingkasan += 50;
                }

                int biayaAdmin = subtotal > 0
                    ? hitungBiayaAdmin(
                            _selectedPayment ?? "", subtotal + _ongkirValue)
                        .toInt()
                    : 0;
                int totalFinal =
                    subtotal > 0 ? (subtotal + _ongkirValue + biayaAdmin) : 0;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                            Icons.local_shipping, "Alamat Pengiriman"),
                        const SizedBox(height: 10),
                        _buildWhiteCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInput("NAMA PENERIMA", _namaController),
                              _buildInput("NOMOR TELEPON", _teleponController),
                              const Text("KECAMATAN, KOTA, PROVINSI",
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _cariWilayahController,
                                style: TextStyle(
                                    color: textBrown,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: inputBg,
                                  hintText:
                                      "Ketik min. 3 huruf (Cth: Bukit Bestari)",
                                  hintStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.normal),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 15, vertical: 10),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none),
                                ),
                                onChanged: (value) =>
                                    _searchWilayahBiteship(value),
                              ),
                              if (_searchResults.isNotEmpty)
                                Container(
                                  margin:
                                      const EdgeInsets.only(top: 8, bottom: 8),
                                  constraints:
                                      const BoxConstraints(maxHeight: 180),
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 4,
                                            offset: Offset(0, 2))
                                      ],
                                      border: Border.all(
                                          color: Colors.grey.shade300)),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics: const ClampingScrollPhysics(),
                                    padding: EdgeInsets.zero,
                                    itemCount: _searchResults.length,
                                    separatorBuilder: (context, index) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final area = _searchResults[index];
                                      String name = area['name'] ?? "";
                                      String adminLvl3 = area[
                                              'administrative_division_level_3'] ??
                                          "";
                                      String namaLengkap = "$name, $adminLvl3"
                                          .replaceAll(", ,", ", ")
                                          .replaceAll("null", "")
                                          .trim();

                                      if (namaLengkap.endsWith(",")) {
                                        namaLengkap = namaLengkap
                                            .substring(
                                                0, namaLengkap.length - 1)
                                            .trim();
                                      }

                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 2),
                                        title: Text(
                                          namaLengkap,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: textBrown,
                                              fontWeight: FontWeight.w600),
                                        ),
                                        onTap: () {
                                          String defaultKurir = 'JNE';

                                          setState(() {
                                            _selectedAreaId = area['id'];
                                            _selectedWilayahNama = namaLengkap;
                                            _cariWilayahController.text =
                                                namaLengkap;
                                            _searchResults = [];

                                            if (area['postal_code'] != null) {
                                              _autoPostalCode =
                                                  area['postal_code']
                                                      .toString();
                                            }
                                          });

                                          _hitungOngkirBiteship(
                                              defaultKurir, totalBeratGram);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              const SizedBox(height: 12),
                              _buildInput("KELURAHAN", _kelurahanController),
                              _buildInput(
                                  "DETAIL ALAMAT", _detailAlamatController),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                        _buildSectionHeader(Icons.local_post_office_outlined,
                            "Pilihan Ekspedisi"),
                        const SizedBox(height: 10),
                        _buildWhiteCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCourierTile(
                                  "JNE",
                                  _selectedCourier == "JNE" && _isLoadingOngkir
                                      ? "Menghitung..."
                                      : _jneEta,
                                  totalBeratGram,
                                  _jneTersedia),
                              _buildCourierTile(
                                  "J&T (JNT)",
                                  _selectedCourier == "J&T (JNT)" &&
                                          _isLoadingOngkir
                                      ? "Menghitung..."
                                      : _jntEta,
                                  totalBeratGram,
                                  _jntTersedia),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                        _buildSectionHeader(
                            Icons.account_balance_wallet, "Metode Pembayaran"),
                        const SizedBox(height: 10),
                        _buildWhiteCard(
                          child: Column(
                            children: _metodePembayaranList.map((payment) {
                              return _buildPaymentTileCustom(
                                bankName: payment['nama']!,
                                rawDetail: payment['kode']!,
                                totalBelanjaSekarang: subtotal + _ongkirValue,
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 25),
                        _buildSectionHeader(
                            Icons.shopping_bag, "Ringkasan Pesanan"),
                        const SizedBox(height: 10),
                        _buildWhiteCard(
                          child: Column(
                            children: [
                              ...checkoutItems.map((item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: _buildProductItem(
                                      item['namaProduk'],
                                      item['rasa'],
                                      item['ukuran'],
                                      item['jumlah'].toString(),
                                      item['hargaSatuan'].toString(),
                                      item['image_url'],
                                    ),
                                  )),
                              const Divider(height: 30),
                              _priceRow("Subtotal Produk",
                                  _currencyFormat.format(subtotal)),
                              _priceRow(
                                  "Ongkos Kirim (${_selectedCourier ?? 'Belum Dipilih'})",
                                  _isLoadingOngkir
                                      ? "Menghitung..."
                                      : (_selectedCourier == null
                                          ? "-"
                                          : _currencyFormat
                                              .format(_ongkirValue))),
                              _priceRow(
                                  "Biaya Admin",
                                  _selectedPayment == null
                                      ? "-"
                                      : _currencyFormat.format(biayaAdmin)),
                              _priceRow("Total Estimasi Berat",
                                  "$beratTampilRingkasan Gram"),
                              const Divider(),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Total Bayar",
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: textBrown)),
                                  Text(_currencyFormat.format(totalFinal),
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade900)),
                                ],
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryYellow,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(25)),
                                  ),
                                  onPressed: checkoutItems.isEmpty ||
                                          _isLoadingOngkir ||
                                          (_selectedCourier != null &&
                                              _ongkirValue == 0)
                                      ? null
                                      : () => _navigateToPayment(subtotal,
                                          totalBeratGram, _ongkirValue),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.verified_user,
                                          color: Colors.black, size: 18),
                                      SizedBox(width: 8),
                                      Text("Lanjutkan Ke Pembayaran",
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildCourierTile(
      String name, String estimation, int totalBerat, bool isAvailable) {
    return RadioListTile<String>(
      title: Text(name,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isAvailable ? textBrown : Colors.grey)),
      subtitle: Text(estimation,
          style: TextStyle(
              fontSize: 11,
              color: isAvailable ? Colors.grey.shade600 : Colors.red.shade400)),
      value: name,
      groupValue: _selectedCourier,
      activeColor: textBrown,
      toggleable: true,
      onChanged: isAvailable
          ? (v) {
              if (v != null) {
                _hitungOngkirBiteship(v, totalBerat);
              }
            }
          : null,
      secondary: Icon(Icons.local_shipping_outlined,
          color: isAvailable ? textBrown : Colors.grey.shade400, size: 24),
    );
  }

  // =========================================================================
  // 💎 WIDGET CUSTOM PILIHAN PEMBAYARAN (FIXED SUBTITLE TIDAK DOUBLE NAMA BANK)
  // =========================================================================
  Widget _buildPaymentTileCustom({
    required String bankName,
    required String rawDetail,
    required int totalBelanjaSekarang,
  }) {
    double adminFeeSim = hitungBiayaAdmin(bankName, totalBelanjaSekarang);

    // Langsung buat teks info admin / keterangan tanpa mengulang nama bank di depannya
    String subTextInfo = adminFeeSim > 0
        ? "+ Biaya Admin ${_currencyFormat.format(adminFeeSim)}"
        : "Bebas Biaya Admin";

    return RadioListTile<String>(
      title: Text(bankName.toUpperCase(),
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: textBrown)),
      subtitle: Text(subTextInfo,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      value: bankName,
      groupValue: _selectedPayment,
      activeColor: textBrown,
      onChanged: (v) {
        setState(() {
          _selectedPayment = v;
          _selectedPaymentDetail = rawDetail;
        });
      },
    );
  }

  Widget _buildInput(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 5),
          TextFormField(
            controller: controller,
            style: TextStyle(
                color: textBrown, fontSize: 14, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              filled: true,
              fillColor: inputBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF8D6E63)),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: textBrown)),
      ],
    );
  }

  Widget _buildWhiteCard({required Widget child}) {
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: child);
  }

  Widget _buildProductItem(String name, String rasa, String sz, String qty,
      String prc, String imageUrl) {
    Widget itemImageWidget;
    try {
      if (imageUrl.startsWith("data:image")) {
        itemImageWidget = Image.memory(base64Decode(imageUrl.split(',').last),
            fit: BoxFit.cover, width: double.infinity, height: double.infinity);
      } else if (imageUrl.isNotEmpty) {
        itemImageWidget = Image.network(imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.fastfood, color: Colors.orange));
      } else {
        itemImageWidget = const Icon(Icons.fastfood, color: Colors.orange);
      }
    } catch (e) {
      itemImageWidget = const Icon(Icons.broken_image, color: Colors.red);
    }
    return Row(
      children: [
        Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
                color: bgCream, borderRadius: BorderRadius.circular(12)),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: itemImageWidget)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text("Varian: $rasa",
              style: TextStyle(fontSize: 11, color: textBrown)),
          Text("UKURAN: $sz | JUMLAH: $qty",
              style: const TextStyle(fontSize: 10, color: Colors.grey))
        ])),
        Text(_currencyFormat.format(int.parse(prc) * int.parse(qty)),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _priceRow(String lab, String val) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
              child: Text(lab,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 10),
          Text(val,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))
        ]));
  }

  Widget _buildBottomNav() {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_outlined, "Beranda", 0),
          _navItem(Icons.receipt_long, "Riwayat Pesanan", 1),
          _navItem(Icons.person_outline, "Akun", 2)
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool active = index == 1;
    return InkWell(
      onTap: () {
        if (index == 0) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const HomePage()));
        }
        if (index == 1) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const TransactionHistoryPage()));
        }
        if (index == 2) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const ProfilePage()));
        }
      },
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
                color: active ? const Color(0xFFFFE082) : Colors.transparent,
                borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: textBrown)),
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))
      ]),
    );
  }
}
