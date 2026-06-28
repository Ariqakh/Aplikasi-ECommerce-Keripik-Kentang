import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart'; // Import model yang tadi

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Fungsi Registrasi
  Future<String?> registerUser({
    required String nama,
    required String email,
    required String password,
  }) async {
    try {
      // Buat akun di Firebase Auth
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Jika berhasil, buat objek UserModel
      UserModel newUser = UserModel(
        uid: userCredential.user!.uid,
        nama: nama,
        email: email,
        role: 'pembeli', // Default saat daftar adalah pembeli
        createdAt: DateTime.now(),
      );

      // Simpan ke Firestore
      await _db.collection('users').doc(newUser.uid).set(newUser.toMap());

      return "success";
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // 2. Fungsi Login
  Future<UserModel?> loginUser(String email, String password) async {
    try {
      // Login ke Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Ambil data detail user dari Firestore berdasarkan UID
      DocumentSnapshot doc =
          await _db.collection('users').doc(userCredential.user!.uid).get();

      if (doc.exists) {
        // Ubah data Firestore menjadi UserModel
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print("Error Login: $e");
      return null;
    }
  }

  // 3. Fungsi Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 4. Cek User yang sedang login (untuk auto-login)
  Stream<User?> get userStream => _auth.authStateChanges();
}
