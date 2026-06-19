import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/record.dart';

void main() {
  group('MapPoint', () {
    test('toMap ve fromMap dönüşümü doğru çalışmalı', () {
      final point = const MapPoint(
        latitude: 39.9334,
        longitude: 32.8597,
        label: 'Ankara',
      );
      final map = point.toMap();

      expect(map['latitude'], 39.9334);
      expect(map['longitude'], 32.8597);
      expect(map['label'], 'Ankara');

      final restored = MapPoint.fromMap(map);
      expect(restored.latitude, 39.9334);
      expect(restored.longitude, 32.8597);
      expect(restored.label, 'Ankara');
    });

    test('label null olabilir', () {
      final point = const MapPoint(
        latitude: 41.0082,
        longitude: 28.9784,
      );
      final map = point.toMap();

      expect(map['label'], isNull);
      expect(point.label, isNull);
    });
  });

  group('MapPoint karşılaştırma', () {
    test('aynı değerlere sahip noktalar eşit olmalı', () {
      const a = MapPoint(
        latitude: 39.9334,
        longitude: 32.8597,
        label: 'Test',
      );
      const b = MapPoint(
        latitude: 39.9334,
        longitude: 32.8597,
        label: 'Test',
      );
      expect(a.latitude, b.latitude);
      expect(a.longitude, b.longitude);
      expect(a.label, b.label);
    });
  });
}
