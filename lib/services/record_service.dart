import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/record.dart';

class RecordService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser?.uid ?? '';

  /// Yeni kayıt oluştur
  Future<void> saveRecord({
    required List<MapPoint> points,
    String? title,
    required String text,
    String? photoBase64,
  }) async {
    if (_userId.isEmpty) return;

    final data = <String, dynamic>{
      'userId': _userId,
      'points': points.map((p) => p.toMap()).toList(),
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (title != null && title.isNotEmpty) {
      data['title'] = title;
    }
    if (photoBase64 != null) {
      data['photoBase64'] = photoBase64;
    }
    await _firestore.collection('records').add(data);
  }

  /// Kullanıcının tüm kayıtlarını getir (en yeniden eskiye)
  Stream<List<Record>> getRecords() {
    if (_userId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('records')
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Record.fromFirestore(doc)).toList());
  }

  /// Tek bir kaydı sil
  Future<void> deleteRecord(String recordId) async {
    await _firestore.collection('records').doc(recordId).delete();
  }

  /// Kaydı güncelle
  Future<void> updateRecord({
    required String recordId,
    required List<MapPoint> points,
    String? title,
    required String text,
  }) async {
    await _firestore.collection('records').doc(recordId).update({
      'points': points.map((p) => p.toMap()).toList(),
      if (title != null && title.isNotEmpty) 'title': title,
      'text': text,
    });
  }
}
