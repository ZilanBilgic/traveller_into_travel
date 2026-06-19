import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Harita üzerinde işaretlenen nokta (OpenStreetMap koordinatları)
class MapPoint {
  final double latitude;   // Enlem (Örn: 39.9334)
  final double longitude;  // Boylam (Örn: 32.8597)
  final String? label;
  final String? note;
  final String? photoBase64; // Noktaya ait fotoğraf (dosya yolu veya eski base64)

  const MapPoint({
    required this.latitude,
    required this.longitude,
    this.label,
    this.note,
    this.photoBase64,
  });

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'label': label,
        'note': note,
        if (photoBase64 != null) 'photoBase64': photoBase64,
      };

  factory MapPoint.fromMap(Map<String, dynamic> map) => MapPoint(
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        label: map['label'] as String?,
        note: map['note'] as String?,
        photoBase64: map['photoBase64'] as String?,
      );
}

/// Fotoğraf verisinden Image widget'ı oluşturur.
/// - `data:` ile başlıyorsa → eski base64 formatı, memory'den çözülür
/// - Diğer durumda → yeni dosya yolu formatı, diskten okunur
Widget buildPhotoImage(
  String? photoData, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget? placeholder,
}) {
  if (photoData == null || photoData.isEmpty) {
    return placeholder ?? const SizedBox.shrink();
  }

  if (photoData.startsWith('data:')) {
    // Eski base64 formatı
    return Image.memory(
      base64Decode(photoData.split(',').last),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) =>
          placeholder ??
          const Icon(Icons.broken_image_outlined, color: Colors.grey),
    );
  }

  // Yeni dosya yolu formatı
  return Image.file(
    File(photoData),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, __, ___) =>
        placeholder ??
        const Icon(Icons.broken_image_outlined, color: Colors.grey),
  );
}

/// Kullanıcının oluşturduğu kayıt
class Record {
  final String id;
  final String userId;
  final List<MapPoint> points;
  final String? title; // Genel başlık
  final String text;
  final String? photoBase64; // Genel not fotoğrafı (dosya yolu veya eski base64)
  final DateTime createdAt;

  const Record({
    required this.id,
    required this.userId,
    required this.points,
    this.title,
    required this.text,
    this.photoBase64,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'points': points.map((p) => p.toMap()).toList(),
        if (title != null && title!.isNotEmpty) 'title': title,
        'text': text,
        if (photoBase64 != null) 'photoBase64': photoBase64,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory Record.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final pointsList = (data['points'] as List<dynamic>?) ?? [];

    return Record(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      points: pointsList
          .map((p) => MapPoint.fromMap(p as Map<String, dynamic>))
          .toList(),
      title: data['title'] as String?,
      text: data['text'] as String? ?? '',
      photoBase64: data['photoBase64'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
