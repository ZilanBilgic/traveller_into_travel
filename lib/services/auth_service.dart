import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  // Mevcut kullanıcıyı dinle (auth state changes)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Mevcut kullanıcı
  User? get currentUser => _auth.currentUser;

  // Kayıt ol
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String name,
    required String surname,
    required DateTime birthDate,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Firestore'a kullanıcı bilgilerini kaydet
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'email': email.trim(),
        'name': name.trim(),
        'surname': surname.trim(),
        'birthDate': birthDate.toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } on FirebaseAuthException {
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  // Giriş yap
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException {
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  // Çıkış yap
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Kullanıcı bilgilerini getir
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Kullanıcı bilgilerini güncelle
  Future<void> updateUserData({
    required String uid,
    required String name,
    required String surname,
    DateTime? birthDate,
  }) async {
    final updates = <String, dynamic>{
      'name': name.trim(),
      'surname': surname.trim(),
    };
    if (birthDate != null) updates['birthDate'] = birthDate.toIso8601String();

    try {
      await _firestore.collection('users').doc(uid).set(updates, SetOptions(merge: true));
    } on FirebaseException {
      rethrow;
    }
  }

  // Profil fotoğrafı base64 kaydet
  Future<void> saveProfilePhoto({
    required String uid,
    required String base64,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'photoBase64': base64,
    }, SetOptions(merge: true));
  }

  // Profil fotoğrafı sil
  Future<void> deleteProfilePhoto(String uid) async {
    await _firestore.collection('users').doc(uid).set({
      'photoBase64': FieldValue.delete(),
    }, SetOptions(merge: true));
  }
}
