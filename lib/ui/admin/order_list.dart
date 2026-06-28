import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dashboard_admin.dart';
import 'manage_product.dart';

class OrderListPage extends StatefulWidget {
  const OrderListPage({super.key});

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> {
  final Color primaryYellow = const Color(0xFFFFB800);
  final Color bgLight = const Color(0xFFFDF5E6);
  final Color darkBrown = const Color(0xFF422817);
  final Color textGrey = const Color(0xFF8E8E8E);
  final Color statusGold = const Color(0xFF947511);

  int _currentIndex = 2;
  String _selectedFilter = "pembayaran berhasil";

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // Fungsi pembantu hitung biaya admin biar sama dengan halaman user
  int hitungBiayaAdmin(String metode, int total) {
    if (metode.isEmpty) return 0;
    String metodeLower = metode.toLowerCase();
    if (metodeLower.contains("qris")) {
      return (total * 0.009).toInt();
    } else {
      return 4000;
    }
  }

  // PERBAIKAN: Fungsi proteksi alamat agar Map dari Firestore tidak menyebabkan crash tipe data String
  String getAlamatDisplay(dynamic alamat) {
    if (alamat == null) return "Alamat tidak tersedia";

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

    return alamat.toString();
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    if (index == 0) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const DashboardAdminPage()));
    } else if (index == 1) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const ManageProductPage()));
    } else if (index == 2) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  // 📝 TAMPILAN BARU: DETAIL PESANAN KUSTOM DI DALAM FILE INI
  void _tampilkanDialogDetailPesanan(Map<String, dynamic> data,
      String tanggalString, int totalBayar, bool isLokal) {
    showDialog(
      context: context,
      builder: (context) {
        List<dynamic> itemPesanan = data['itemPesanan'] ?? [];
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Detail Pesanan",
                style: TextStyle(
                    color: darkBrown,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
              IconButton(
                icon: Icon(Icons.close, color: darkBrown),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bgLight,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("ID Pesanan:",
                                style:
                                    TextStyle(color: textGrey, fontSize: 12)),
                            Text((data['orderId'] ?? '-').toUpperCase(),
                                style: TextStyle(
                                    color: darkBrown,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Waktu Transaksi:",
                                style:
                                    TextStyle(color: textGrey, fontSize: 12)),
                            Text(tanggalString,
                                style:
                                    TextStyle(color: darkBrown, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Status:",
                                style:
                                    TextStyle(color: textGrey, fontSize: 12)),
                            Text((data['statusPesanan'] ?? '-').toUpperCase(),
                                style: TextStyle(
                                    color: statusGold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text("Informasi Penerima",
                      style: TextStyle(
                          color: darkBrown,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const Divider(),
                  Text("Nama: ${data['namaPenerima'] ?? '-'}",
                      style: TextStyle(color: darkBrown, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                      "No. HP: ${data['teleponPenerima'] ?? (data['nomorTelepon'] ?? '-')}",
                      style: TextStyle(color: darkBrown, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text("Alamat Lengkap:",
                      style: TextStyle(
                          color: textGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  // PERBAIKAN UTAMA DI SINI: Menggunakan getAlamatDisplay agar aman dari error tipe data Map
                  Text(getAlamatDisplay(data['alamatLengkap']),
                      style: TextStyle(
                          color: darkBrown, fontSize: 13, height: 1.3)),
                  const SizedBox(height: 15),
                  Text("Daftar Produk",
                      style: TextStyle(
                          color: darkBrown,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const Divider(),
                  ...itemPesanan.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['namaProduk'] ?? '-',
                                    style: TextStyle(
                                        color: darkBrown,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                Text("Rasa: ${item['rasa'] ?? 'Original'}",
                                    style: TextStyle(
                                        color: textGrey, fontSize: 11)),
                              ],
                            ),
                          ),
                          Text("x${item['jumlah'] ?? 1}",
                              style: TextStyle(
                                  color: darkBrown,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 15),
                  Text("Rincian Pengiriman & Pembayaran",
                      style: TextStyle(
                          color: darkBrown,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Pembayaran:",
                          style: TextStyle(color: textGrey, fontSize: 12)),
                      Text((data['metodePembayaran'] ?? '-').toUpperCase(),
                          style: TextStyle(
                              color: darkBrown,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Kategori Kurir:",
                          style: TextStyle(color: textGrey, fontSize: 12)),
                      Text(isLokal ? "KURIR LOKAL" : "LUAR KEPRI (EKSPEDISI)",
                          style: TextStyle(
                              color: Colors.blue.shade900,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (data['nomorResi'] != null &&
                      data['nomorResi'] != '-') ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isLokal ? "No. Kontak Kurir:" : "Nomor Resi:",
                            style: TextStyle(color: textGrey, fontSize: 12)),
                        Text(
                            "${data['nomorResi']} (${data['ekspedisi'] ?? 'Reguler'})",
                            style: TextStyle(
                                color: Colors.green.shade900,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                  const Divider(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("TOTAL BAYAR:",
                          style: TextStyle(
                              color: darkBrown,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      Text(_currencyFormat.format(totalBayar),
                          style: TextStyle(
                              color: darkBrown,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkBrown,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("TUTUP",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        );
      },
    );
  }

  // 📝 POPUP UNTUK INPUT RESI / NO KURIR, EKSPEDISI, DAN UBAH STATUS OLEH ADMIN
  void _tampilkanBottomSheetKelolaPesanan(String docId, String statusSekarang,
      String resiSekarang, String ekspedisiSekarang,
      {String kurirKategori = 'lokal'}) {
    final TextEditingController resiController =
        TextEditingController(text: resiSekarang == '-' ? '' : resiSekarang);
    final TextEditingController ekspedisiController = TextEditingController(
        text: ekspedisiSekarang == 'Reguler' ||
                ekspedisiSekarang == 'Ekspedisi Pilihan'
            ? ''
            : ekspedisiSekarang);
    String statusTerpilih = statusSekarang.toLowerCase();

    final List<String> daftarStatus = [
      "pembayaran berhasil",
      "pesanan dikonfirmasi",
      "pesanan diproses",
      "dikirim",
      "selesai",
      "dibatalkan"
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30), topRight: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool isLuarKepri = kurirKategori.toLowerCase() != 'lokal';

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 25,
                right: 25,
                top: 25,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(height: 20),
                    Text("Kelola Status & Pengiriman",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkBrown)),
                    const Divider(height: 25),
                    Text("Ubah Status Pesanan",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: darkBrown)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: daftarStatus.contains(statusTerpilih)
                              ? statusTerpilih
                              : daftarStatus.first,
                          isExpanded: true,
                          icon:
                              Icon(Icons.keyboard_arrow_down, color: darkBrown),
                          items: daftarStatus.map((String val) {
                            return DropdownMenuItem<String>(
                              value: val,
                              child: Text(val.toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: darkBrown,
                                      fontWeight: FontWeight.bold)),
                            );
                          }).toList(),
                          onChanged: (newVal) {
                            setModalState(() {
                              statusTerpilih = newVal!;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                        isLuarKepri
                            ? "Nama Ekspedisi (Luar Kepri)"
                            : "Nama Ekspedisi / Transportasi Lokal",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: darkBrown)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ekspedisiController,
                      decoration: InputDecoration(
                        hintText: isLuarKepri
                            ? "Contoh: J&T, JNE, Sicepat"
                            : "Contoh: Kurir Lokal Toko, Gojek, Grab",
                        hintStyle: TextStyle(color: textGrey, fontSize: 13),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: primaryYellow, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                        isLuarKepri
                            ? "Nomor Resi Pengiriman"
                            : "Nomor Resi / Kontak Kurir",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: darkBrown)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: resiController,
                      keyboardType: isLuarKepri
                          ? TextInputType.text
                          : TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: isLuarKepri
                            ? "Masukkan nomor resi resmi ekspedisi"
                            : "Masukkan nomor",
                        hintStyle: TextStyle(color: textGrey, fontSize: 13),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: primaryYellow, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryYellow,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          if (statusTerpilih == 'dikirim' &&
                              resiController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isLuarKepri
                                    ? "Gagal! Nomor resi luar kepri wajib diisi jika status dikirim."
                                    : "Gagal! Kontak nomor kurir lokal wajib diisi jika status dikirim."),
                              ),
                            );
                            return;
                          }

                          try {
                            await FirebaseFirestore.instance
                                .collection('orders')
                                .doc(docId)
                                .update({
                              'statusPesanan': statusTerpilih,
                              'nomorResi': resiController.text.trim().isEmpty
                                  ? '-'
                                  : resiController.text.trim(),
                              'ekspedisi':
                                  ekspedisiController.text.trim().isEmpty
                                      ? 'Reguler'
                                      : ekspedisiController.text.trim(),
                            });
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text("Pesanan berhasil diperbarui!")),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text("Gagal memperbarui: $e")));
                            }
                          }
                        },
                        child: Text("SIMPAN PERUBAHAN",
                            style: TextStyle(
                                color: darkBrown,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: Column(
        children: [
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
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 40,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.cookie, color: primaryYellow, size: 30),
                ),
                const SizedBox(width: 12),
                Text(
                  "DAFTAR PESANAN",
                  style: TextStyle(
                    color: darkBrown,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 55,
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildFilterButton("pembayaran berhasil"),
                _buildFilterButton("pesanan dikonfirmasi"),
                _buildFilterButton("pesanan diproses"),
                _buildFilterButton("dikirim"),
                _buildFilterButton("selesai"),
                _buildFilterButton("dibatalkan"),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('statusPesanan', isEqualTo: _selectedFilter)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(color: darkBrown));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 60, color: textGrey),
                        const SizedBox(height: 10),
                        Text(
                          "Tidak ada pesanan dengan status ini.",
                          style: TextStyle(color: textGrey, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  physics: const BouncingScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;

                    String orderId = data['orderId'] ?? 'ID-MISSING';
                    String docId = doc.id;
                    String namaPenerima = data['namaPenerima'] ?? 'Pelanggan';
                    String metodeBayar = data['metodePembayaran'] ?? '-';
                    String statusPesanan =
                        data['statusPesanan'] ?? 'pembayaran berhasil';
                    String nomorResi = data['nomorResi'] ?? '-';
                    String ekspedisi = data['ekspedisi'] ?? 'Reguler';

                    String kurirKategori = data['kurirKategori'] ?? 'lokal';
                    bool isLokal = kurirKategori.toLowerCase() == 'lokal';

                    int totalHargaProduk = data['totalHargaProduk'] ?? 0;
                    int ongkosKirim = data['ongkosKirim'] ?? 0;

                    int biayaAdmin = data['biayaAdmin'] ??
                        hitungBiayaAdmin(
                            metodeBayar, totalHargaProduk + ongkosKirim);
                    int totalBayar =
                        totalHargaProduk + ongkosKirim + biayaAdmin;

                    String tanggalString = "Baru Saja";
                    if (data['createdAt'] != null) {
                      DateTime dt = (data['createdAt'] as Timestamp).toDate();
                      tanggalString =
                          DateFormat('dd MMM yyyy, HH:mm').format(dt);
                    }

                    List<dynamic> itemPesanan = data['itemPesanan'] ?? [];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
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
                                "ID: ${orderId.toUpperCase()}",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: darkBrown,
                                    fontSize: 14),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: bgLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  statusPesanan.toUpperCase(),
                                  style: TextStyle(
                                      color: statusGold,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(tanggalString,
                              style: TextStyle(color: textGrey, fontSize: 11)),
                          const Divider(height: 20),
                          Text("Pemesan: $namaPenerima",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: darkBrown,
                                  fontSize: 13)),
                          const SizedBox(height: 5),
                          Text("Produk yang dibeli:",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: textGrey,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Column(
                            children: itemPesanan.map((item) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "- ${item['namaProduk']} (${item['rasa'] ?? 'Original'})",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12, color: darkBrown),
                                      ),
                                    ),
                                    Text("x${item['jumlah'] ?? 1}",
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: darkBrown)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Metode: ${metodeBayar.toUpperCase()}",
                                      style: TextStyle(
                                          color: textGrey, fontSize: 11)),
                                  if (nomorResi != '-')
                                    Text(
                                        isLokal
                                            ? "No. Kurir Lokal: $nomorResi ($ekspedisi)"
                                            : "Resi Luar Kepri: $nomorResi ($ekspedisi)",
                                        style: TextStyle(
                                            color: Colors.blue.shade900,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("Total Bayar (+Admin)",
                                      style: TextStyle(
                                          color: textGrey, fontSize: 10)),
                                  Text(_currencyFormat.format(totalBayar),
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: darkBrown,
                                          fontSize: 15)),
                                ],
                              )
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 38,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color: darkBrown, width: 1),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                    onPressed: () {
                                      _tampilkanDialogDetailPesanan(data,
                                          tanggalString, totalBayar, isLokal);
                                    },
                                    icon: Icon(Icons.visibility,
                                        size: 16, color: darkBrown),
                                    label: Text("Lihat Detail",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: darkBrown,
                                            fontSize: 12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 38,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: bgLight,
                                      foregroundColor: darkBrown,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      side: BorderSide(
                                          color: primaryYellow, width: 1),
                                    ),
                                    onPressed: () =>
                                        _tampilkanBottomSheetKelolaPesanan(
                                            docId,
                                            statusPesanan,
                                            nomorResi,
                                            ekspedisi,
                                            kurirKategori: kurirKategori),
                                    icon: const Icon(Icons.edit_note, size: 18),
                                    label: const Text("Kelola Pesanan",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
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

  Widget _buildFilterButton(String filterValue) {
    bool isSelected = _selectedFilter == filterValue;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      alignment: Alignment.center,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? darkBrown : Colors.white,
          foregroundColor: isSelected ? Colors.white : darkBrown,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(
                color: isSelected ? darkBrown : Colors.grey.shade300),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        onPressed: () {
          setState(() {
            _selectedFilter = filterValue;
          });
        },
        child: Text(
          filterValue.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(40), topRight: Radius.circular(40)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.analytics_outlined, "ANALISIS", 0),
          _navItem(Icons.inventory_2_outlined, "PRODUK", 1),
          _navItem(Icons.receipt_long_rounded, "PESANAN", 2),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool active = _currentIndex == index;
    return InkWell(
      onTap: () => _onTabTapped(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? darkBrown : textGrey, size: 28),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: active ? darkBrown : textGrey)),
          if (active)
            Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration:
                    BoxDecoration(color: darkBrown, shape: BoxShape.circle))
        ],
      ),
    );
  }
}
