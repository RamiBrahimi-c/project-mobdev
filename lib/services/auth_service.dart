import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // validation email
  bool isValidEmail(String email) {
    final regex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    return regex.hasMatch(email);
  }

  // Vérifier +13 ans
  bool isAtLeast13(DateTime dob) {
    final now = DateTime.now();
    return now.year - dob.year >= 13;
  }

  Future<void> signup({
    required String firstName,
    required String lastName,
    required DateTime dob,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _db.collection("users").doc(cred.user!.uid).set({
      "firstName": firstName,
      "lastName": lastName,
      "dob": dob.toString().split(" ")[0],
      "email": email,
    });
  }

  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<Map<String, dynamic>> getProfile(String uid) async {
    final doc = await _db.collection("users").doc(uid).get();
    return doc.data()!;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
  
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }  
  
}