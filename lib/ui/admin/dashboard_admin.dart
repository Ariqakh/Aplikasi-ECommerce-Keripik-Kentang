import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'manage_product.dart';
import 'order_list.dart';
import 'profile_admin.dart';
import '../user/order_status_page.dart'; // Mengimport halaman chat room

class DashboardAdminPage extends StatefulWidget {
  const DashboardAdminPage({super.key});

  @override
  State<DashboardAdminPage> createState() => _DashboardAdminPageState();
}

class _DashboardAdminPageState extends State<DashboardAdminPage> {
  final Color primaryYellow = const Color(0xFFFFB800);
  final Color bgLight = const Color(0xFFFDF5E6);
  final Color darkBrown = const Color(0xFF422817);
  final Color textGrey = const Color(0xFF8E8E8E);

  String selectedFilter = "Minggu ini";

  int selectedBulanUtama = DateTime.now().month;
  int selectedTanggalSub = DateTime.now().day;

  int selectedTahunUtama = DateTime.now().year;
  int selectedBulanSub = DateTime.now().month;

  bool _showAllChatsOnly = false;

  final List<String> _namaBulanLengkap = [
    "Januari",
    "Februari",
    "Maret",
    "April",
    "Mei",
    "Juni",
    "Juli",
    "Agustus",
    "September",
    "Oktober",
    "November",
    "Desember"
  ];

  DateTime _getFilterStartDate() {
    DateTime now = DateTime.now();
    if (selectedFilter == "Hari ini") {
      return DateTime(now.year, now.month, now.day);
    } else if (selectedFilter == "Minggu ini") {
      int daysToSubtract = now.weekday - 1;
      DateTime startOfWeek = now.subtract(Duration(days: daysToSubtract));
      return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    } else if (selectedFilter == "Bulan") {
      return DateTime(now.year, selectedBulanUtama, selectedTanggalSub);
    } else {
      return DateTime(selectedTahunUtama, selectedBulanSub, 1);
    }
  }

  DateTime _getFilterEndDate() {
    DateTime start = _getFilterStartDate();
    if (selectedFilter == "Hari ini") {
      return start.add(const Duration(days: 1));
    } else if (selectedFilter == "Minggu ini") {
      return start.add(const Duration(days: 7));
    } else if (selectedFilter == "Bulan") {
      return start
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));
    } else {
      return DateTime(start.year, start.month + 1, 1)
          .subtract(const Duration(seconds: 1));
    }
  }

  Map<String, dynamic> _processChartStatistics(
      List<QueryDocumentSnapshot> docs) {
    List<double> values = [];
    List<String> labels = [];

    if (selectedFilter == "Hari ini" || selectedFilter == "Bulan") {
      values = List.filled(5, 0.0);
      labels = ["00:00", "06:00", "12:00", "18:00", "24:00"];
      for (var doc in docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data['createdAt'] != null) {
          DateTime dt = (data['createdAt'] as Timestamp).toDate();
          int index = dt.hour ~/ 6;
          if (index >= 0 && index < 5) {
            values[index] += (data['totalBayar'] ?? 0).toDouble();
          }
        }
      }
    } else if (selectedFilter == "Minggu ini") {
      values = List.filled(7, 0.0);
      labels = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"];
      for (var doc in docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data['createdAt'] != null) {
          DateTime dt = (data['createdAt'] as Timestamp).toDate();
          int index = dt.weekday - 1;
          if (index >= 0 && index < 7) {
            values[index] += (data['totalBayar'] ?? 0).toDouble();
          }
        }
      }
    } else {
      values = List.filled(4, 0.0);
      String bulanTerpilih = _namaBulanLengkap[selectedBulanSub - 1];
      labels = [
        "$bulanTerpilih M1",
        "$bulanTerpilih M2",
        "$bulanTerpilih M3",
        "$bulanTerpilih M4"
      ];
      for (var doc in docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data['createdAt'] != null) {
          DateTime dt = (data['createdAt'] as Timestamp).toDate();
          int index = (dt.day - 1) ~/ 7;
          if (index >= 4) index = 3;
          values[index] += (data['totalBayar'] ?? 0).toDouble();
        }
      }
    }

    double maxVal = values.isEmpty ? 0 : values.reduce(max);
    if (maxVal == 0) maxVal = 1.0;
    List<double> normalizedPoints = values.map((e) => e / maxVal).toList();
    return {"points": normalizedPoints, "labels": labels};
  }

  Map<String, int> _processFlavorStatistics(List<QueryDocumentSnapshot> docs) {
    Map<String, int> flavorMap = {};
    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['itemPesanan'] != null) {
        var items = data['itemPesanan'] as List<dynamic>;
        for (var item in items) {
          if (item is Map<String, dynamic>) {
            String rasa = item['rasa'] ?? item['varian'] ?? 'Original';
            int qty = 0;
            if (item['jumlah'] != null) {
              qty = int.tryParse(item['jumlah'].toString()) ?? 1;
            } else if (item['qty'] != null) {
              qty = int.tryParse(item['qty'].toString()) ?? 1;
            } else {
              qty = 1;
            }
            flavorMap[rasa] = (flavorMap[rasa] ?? 0) + qty;
          }
        }
      }
    }
    return flavorMap;
  }

  void _bukaHalamanBalasChat(String orderDocId, String orderId,
      String userEmail, List<dynamic> currentChatMessages) async {
    if (currentChatMessages.isNotEmpty) {
      List<dynamic> updatedMessages = List.from(currentChatMessages);
      Map<String, dynamic> lastMsg = Map.from(updatedMessages.last);

      if (lastMsg['isRead'] == false) {
        lastMsg['isRead'] = true;
        updatedMessages[updatedMessages.length - 1] = lastMsg;

        await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderDocId)
            .update({'chatMessages': updatedMessages});
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InternalChatRoom(
          orderDocId: orderDocId,
          orderId: orderId,
          userId: 'admin_panel',
          userEmail: userEmail,
          isAdmin: true,
        ),
      ),
    );
  }

  // =========================================================================
  // 🔥 FUNGSI PEMBANTU: MEMPROSES & MENGURUTKAN LIST CHAT DARI SNAPSHOT FIRESTORE
  // =========================================================================
  List<Map<String, dynamic>> _getProcessedAndSortedChats(
      QuerySnapshot snapshot) {
    List<Map<String, dynamic>> listPesan = [];

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      List<dynamic> chatMessages = data['chatMessages'] ?? [];

      if (chatMessages.isNotEmpty) {
        var lastMsg = chatMessages.last;

        // Cek timestamp kustom lastChatAt, jika tidak ada fallback ke createdAt pesanan
        DateTime sortingTime = data['lastChatAt'] != null
            ? (data['lastChatAt'] as Timestamp).toDate()
            : (data['createdAt'] as Timestamp).toDate();

        listPesan.add({
          'docId': doc.id,
          'orderId': data['orderId'] ?? 'Tanpa ID',
          'namaPenerima': data['namaPenerima'] ?? 'Pelanggan',
          'text': lastMsg['text'] ?? '',
          'time': lastMsg['time'] ?? '',
          'isRead': lastMsg['isRead'] ?? true,
          'allMessages': chatMessages,
          'sortingTime': sortingTime, // Disimpan untuk parameter pengurutan
        });
      }
    }

    // Urutkan berdasarkan sortingTime paling baru (Descending)
    listPesan.sort((a, b) => b['sortingTime'].compareTo(a['sortingTime']));
    return listPesan;
  }

  @override
  Widget build(BuildContext context) {
    DateTime startDate = _getFilterStartDate();
    DateTime endDate = _getFilterEndDate();

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
                const EdgeInsets.only(left: 20, right: 20, top: 50, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (_showAllChatsOnly)
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: darkBrown),
                        onPressed: () =>
                            setState(() => _showAllChatsOnly = false),
                      ),
                    Image.asset(
                      'assets/images/logo.png',
                      height: 40,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.cookie, color: primaryYellow, size: 30),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _showAllChatsOnly ? "CHAT PELANGGAN" : "DASHBOARD ADMIN",
                      style: TextStyle(
                          color: darkBrown,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.account_circle_outlined,
                      color: darkBrown, size: 25),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfileAdminPage())),
                ),
              ],
            ),
          ),
          Expanded(
            child: _showAllChatsOnly
                ? _buildFullChatListScreen()
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 25),
                        Text("Halo, Admin",
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: darkBrown)),
                        Text("Berikut ringkasan performa toko Anda.",
                            style: TextStyle(color: textGrey, fontSize: 14)),
                        const SizedBox(height: 25),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('orders')
                              .where('createdAt',
                                  isGreaterThanOrEqualTo: startDate)
                              .where('createdAt', isLessThanOrEqualTo: endDate)
                              .snapshots(),
                          builder: (context, snapshot) {
                            int perluDiproses = 0;
                            int perluDikirim = 0;
                            if (snapshot.hasData) {
                              for (var doc in snapshot.data!.docs) {
                                String status = (doc['statusPesanan'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                if (status == 'pembayaran berhasil' ||
                                    status == 'perlu diproses') {
                                  perluDiproses++;
                                } else if (status == 'pesanan dikonfirmasi' ||
                                    status == 'pesanan diproses' ||
                                    status == 'perlu dikirim') {
                                  perluDikirim++;
                                }
                              }
                            }
                            return Row(
                              children: [
                                _buildSummaryCard(
                                    perluDiproses.toString(),
                                    "Perlu Diproses",
                                    Icons.assignment_late_outlined,
                                    Colors.orange),
                                const SizedBox(width: 15),
                                _buildSummaryCard(
                                    perluDikirim.toString(),
                                    "Perlu Dikirim",
                                    Icons.local_shipping_outlined,
                                    Colors.blue),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 25),
                        _buildInteractiveAnalyticsSection(startDate, endDate),
                        const SizedBox(height: 25),
                        _buildManageProductBanner(),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Chat Pelanggan",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: darkBrown)),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _showAllChatsOnly = true),
                              child: Text("Lihat Semua",
                                  style: TextStyle(
                                      color: primaryYellow,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        StreamBuilder<QuerySnapshot>(
                          // 🛠️ FIX UTAMA DI OPERASIONAL DASHBOARD UTAMA:
                          // Pembacaan chat dibebaskan dari filter orderBy database dan limitasi database
                          // agar chat dari orderan bulan kapan pun yang baru masuk tidak terbuang.
                          stream: FirebaseFirestore.instance
                              .collection('orders')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData)
                              return const Center(
                                  child: CircularProgressIndicator());

                            // Olah data chat secara dinamis lewat function internal
                            List<Map<String, dynamic>> listPesan =
                                _getProcessedAndSortedChats(snapshot.data!);

                            if (listPesan.isEmpty) {
                              return _buildChatTile(
                                  "OBROLAN MASUK",
                                  "Belum ada obrolan masuk.",
                                  "--:--",
                                  false,
                                  () {});
                            }

                            // Tampilkan max 3 data chat teratas di dashboard utama admin
                            return Column(
                              children: listPesan.take(3).map((chat) {
                                String rawId = chat['orderId'];
                                String docId = chat['docId'];
                                String namaUser = chat['namaPenerima'];
                                bool unread = chat['isRead'] == false;
                                return _buildChatTile(
                                    "Order: $rawId ($namaUser)",
                                    chat['text'],
                                    chat['time'],
                                    unread,
                                    () => _bukaHalamanBalasChat(docId, rawId,
                                        namaUser, chat['allMessages']));
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildFullChatListScreen() {
    return StreamBuilder<QuerySnapshot>(
      // 🛠️ FIX UTAMA DI FULL SCREEN CHAT:
      // Menghapus aturan query database yang kaku, beralih ke pembacaan stream real-time global
      // yang diurutkan secara lokal berdasarkan pesan paling baru masuk.
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        // Urutkan chat lewat logic internal penanggalan
        List<Map<String, dynamic>> listPesan =
            _getProcessedAndSortedChats(snapshot.data!);

        if (listPesan.isEmpty) {
          return Center(
              child: Text("Tidak ada riwayat obrolan.",
                  style: TextStyle(color: textGrey)));
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: listPesan.length,
          itemBuilder: (context, index) {
            final chat = listPesan[index];
            String rawId = chat['orderId'];
            String docId = chat['docId'];
            String namaUser = chat['namaPenerima'];
            bool unread = chat['isRead'] == false;
            return _buildChatTile(
                "Order: $rawId ($namaUser)",
                chat['text'],
                chat['time'],
                unread,
                () => _bukaHalamanBalasChat(
                    docId, rawId, namaUser, chat['allMessages']));
          },
        );
      },
    );
  }

  Widget _buildSummaryCard(
      String count, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(count,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: darkBrown)),
            Text(label, style: TextStyle(fontSize: 12, color: textGrey)),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveAnalyticsSection(
      DateTime startDate, DateTime endDate) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate)
          .snapshots(),
      builder: (context, snapshot) {
        List<QueryDocumentSnapshot> orderDocs = snapshot.data?.docs ?? [];
        var flavorStats = _processFlavorStatistics(orderDocs);
        var statResult = _processChartStatistics(orderDocs);
        List<double> normalizedPoints = statResult['points'];
        List<String> labels = statResult['labels'];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(25)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Analitik Toko",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: darkBrown)),
                  Row(
                    children: [
                      if (selectedFilter == "Bulan") ...[
                        DropdownButton<int>(
                          value: selectedBulanUtama,
                          underline: const SizedBox(),
                          icon: Icon(Icons.arrow_drop_down,
                              size: 14, color: primaryYellow),
                          items: List.generate(12, (index) => index + 1)
                              .map((int val) {
                            return DropdownMenuItem<int>(
                                value: val,
                                child: Text(
                                    _namaBulanLengkap[val - 1].substring(0, 3),
                                    style: const TextStyle(fontSize: 11)));
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => selectedBulanUtama = val!),
                        ),
                        DropdownButton<int>(
                          value: selectedTanggalSub,
                          underline: const SizedBox(),
                          icon: Icon(Icons.arrow_drop_down,
                              size: 14, color: primaryYellow),
                          items: List.generate(31, (index) => index + 1)
                              .map((int val) {
                            return DropdownMenuItem<int>(
                                value: val,
                                child: Text("Tgl $val",
                                    style: const TextStyle(fontSize: 11)));
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => selectedTanggalSub = val!),
                        ),
                      ],
                      if (selectedFilter == "Tahun") ...[
                        DropdownButton<int>(
                          value: selectedTahunUtama,
                          underline: const SizedBox(),
                          icon: Icon(Icons.arrow_drop_down,
                              size: 14, color: primaryYellow),
                          items: [DateTime.now().year, DateTime.now().year - 1]
                              .map((int val) {
                            return DropdownMenuItem<int>(
                                value: val,
                                child: Text("$val",
                                    style: const TextStyle(fontSize: 11)));
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => selectedTahunUtama = val!),
                        ),
                        DropdownButton<int>(
                          value: selectedBulanSub,
                          underline: const SizedBox(),
                          icon: Icon(Icons.arrow_drop_down,
                              size: 14, color: primaryYellow),
                          items: List.generate(12, (index) => index + 1)
                              .map((int val) {
                            return DropdownMenuItem<int>(
                                value: val,
                                child: Text(
                                    _namaBulanLengkap[val - 1].substring(0, 3),
                                    style: const TextStyle(fontSize: 11)));
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => selectedBulanSub = val!),
                        ),
                      ],
                      DropdownButton<String>(
                        value: selectedFilter,
                        underline: const SizedBox(),
                        icon: Icon(Icons.keyboard_arrow_down,
                            size: 16, color: darkBrown),
                        items: ["Hari ini", "Minggu ini", "Bulan", "Tahun"]
                            .map((String value) {
                          return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)));
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedFilter = val!;
                            selectedBulanUtama = DateTime.now().month;
                            selectedTanggalSub = DateTime.now().day;
                            selectedTahunUtama = DateTime.now().year;
                            selectedBulanSub = DateTime.now().month;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text("Perbandingan Varian Terlaris",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: darkBrown)),
              const SizedBox(height: 12),
              if (flavorStats.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                      "Belum ada varian produk terjual pada periode ini.",
                      style: TextStyle(
                          color: textGrey,
                          fontSize: 12,
                          fontStyle: FontStyle.italic)),
                )
              else
                ...flavorStats.entries.map((entry) {
                  int maxQty = flavorStats.values.reduce(max);
                  double percentage = maxQty > 0 ? entry.value / maxQty : 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: darkBrown,
                                    fontWeight: FontWeight.w500)),
                            Text("${entry.value} pcs",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: textGrey,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                              value: percentage,
                              backgroundColor: bgLight,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(primaryYellow),
                              minHeight: 7),
                        ),
                      ],
                    ),
                  );
                }),
              const Divider(height: 30, thickness: 1),
              Text("Statistik Pendapatan Penjualan",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: darkBrown)),
              const SizedBox(height: 15),
              SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: CustomPaint(
                      painter:
                          LineChartPainter(primaryYellow, normalizedPoints))),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: labels
                    .map((e) => Text(e,
                        style: TextStyle(
                            color: textGrey,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)))
                    .toList(),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildManageProductBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [darkBrown, const Color(0xFF5D3A24)]),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Inventaris Produk",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text("Cek stok varian rasa dan perbarui harga produk Anda.",
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 12)),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ManageProductPage())),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primaryYellow,
                      foregroundColor: darkBrown,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0),
                  child: const Text("Kelola Produk",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.inventory_2,
              color: primaryYellow.withOpacity(0.3), size: 80),
        ],
      ),
    );
  }

  Widget _buildChatTile(
      String name, String msg, String time, bool unread, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              CircleAvatar(
                  backgroundColor: bgLight,
                  child: Icon(Icons.person, color: darkBrown)),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: darkBrown,
                            fontSize: 15)),
                    Text(msg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: unread ? darkBrown : textGrey,
                            fontSize: 13,
                            fontWeight:
                                unread ? FontWeight.w600 : FontWeight.normal)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(time, style: TextStyle(color: textGrey, fontSize: 11)),
                  if (unread)
                    Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle)),
                ],
              ),
            ],
          ),
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
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.analytics_rounded, "ANALISIS", 0),
          _navItem(Icons.inventory_2_outlined, "PRODUK", 1),
          _navItem(Icons.receipt_long_outlined, "PESANAN", 2),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool active = index == 0;
    return InkWell(
      onTap: () {
        if (index == 0 && _showAllChatsOnly)
          setState(() => _showAllChatsOnly = false);
        if (index == 1)
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const ManageProductPage()));
        if (index == 2)
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const OrderListPage()));
      },
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

class LineChartPainter extends CustomPainter {
  final Color color;
  final List<double> points;
  LineChartPainter(this.color, this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    double xSpacer =
        size.width / (points.length - 1 == 0 ? 1 : points.length - 1);
    for (int i = 0; i < points.length; i++) {
      double x = i * xSpacer;
      double y =
          size.height - (points[i] * (size.height * 0.8) + (size.height * 0.1));
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) =>
      oldDelegate.points != points;
}
