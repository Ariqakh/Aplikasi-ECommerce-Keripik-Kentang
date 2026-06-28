import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String nama;
  final String email;
  final String role; // 'pembeli' atau 'admin'
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.nama,
    required this.email,
    required this.role,
    this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    // Pengecekan aman untuk createdAt agar tidak error saat casting
    DateTime? parsedDate;
    if (data['createdAt'] != null) {
      if (data['createdAt'] is Timestamp) {
        parsedDate = (data['createdAt'] as Timestamp).toDate();
      } else if (data['createdAt'] is String) {
        parsedDate = DateTime.tryParse(data['createdAt']);
      }
    }

    return UserModel(
      uid: data['uid'] ?? '',
      nama: data['nama'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'pembeli',
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nama': nama,
      'email': email,
      'role': role,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
