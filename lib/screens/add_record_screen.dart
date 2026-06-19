import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import '../models/record.dart';
import '../services/record_service.dart';

/// Durak ve opsiyonel not controller'ını bir arada tutan yardımcı sınıf
class _PointEntry {
  MapPoint point;
  TextEditingController? noteController;

  _PointEntry({required this.point});

  String? get label => point.label;
  String? get note => noteController?.text ?? point.note;

  void dispose() => noteController?.dispose();
}

class AddRecordScreen extends StatefulWidget {
  const AddRecordScreen({super.key});

  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen>
    with SingleTickerProviderStateMixin {
  final _recordService = RecordService();
  final _imagePicker = ImagePicker();
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  final _textFocusNode = FocusNode();

  final List<_PointEntry> _entries = [];

  bool _isSaving = false;
  int _charCount = 0;
  String? _recordPhotoBase64; // Genel not fotoğrafı

  // Harita kontrolü
  final MapController _mapController = MapController();

  // Harita animasyonu
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  bool _mapReady = false;

  /// Türkiye merkezi ve başlangıç zoom seviyesi
  static const _turkeyCenter = LatLng(39.0, 35.0);
  static const _initialZoom = 6.5;
  static const _minZoom = 5.0;
  static const _maxZoom = 18.0;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);

    // Harita animasyonu
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _titleController.dispose();
    _textController.dispose();
    _textFocusNode.dispose();
    _animController.dispose();
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    setState(() => _charCount = _textController.text.length);
  }

  /// Galeriden fotoğraf seç, lokal depoya kaydet, dosya yolunu döndür
  Future<String?> _pickPhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 40,
      maxWidth: 300,
      maxHeight: 300,
    );
    if (picked == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${dir.path}/record_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final fileName =
        'photo_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}.jpg';
    final savedPath = '${photosDir.path}/$fileName';
    await File(picked.path).copy(savedPath);
    return savedPath;
  }

  /// Haritaya tıklandığında yeni durak ekle
  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    if (_entries.length >= 10) {
      _showSnackBar('En fazla 10 durak ekleyebilirsiniz');
      return;
    }

    // Çok yakın durak var mı kontrol et (min ~0.3 derece mesafe)
    final tooClose = _entries.any((e) {
      final dLat = (e.point.latitude - latLng.latitude).abs();
      final dLng = (e.point.longitude - latLng.longitude).abs();
      return dLat < 0.3 && dLng < 0.3;
    });

    if (tooClose) {
      _showSnackBar('Bu konuma çok yakın bir durak zaten var');
      return;
    }

    setState(() {
      _entries.add(_PointEntry(
        point: MapPoint(
          latitude: latLng.latitude,
          longitude: latLng.longitude,
        ),
      ));
    });
  }

  /// Noktayı sil
  void _removePoint(int index) {
    setState(() {
      _entries[index].dispose();
      _entries.removeAt(index);
    });
  }

  /// Durak etiketini / notunu düzenleme dialog'u
  void _editPointNote(int index) {
    final entry = _entries[index];
    final labelController =
        TextEditingController(text: entry.point.label ?? '');
    final noteController = TextEditingController(text: entry.note ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Durak Detayı'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Etiket ──
                  TextFormField(
                    controller: labelController,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      labelText: 'Etiket (opsiyonel)',
                      hintText: 'örn: İstanbul, Ankara...',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Not ──
                  TextFormField(
                    controller: noteController,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Not (opsiyonel)',
                      hintText: 'Bu durak hakkında notunuz...',
                      prefixIcon: Icon(Icons.notes_rounded),
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx);
                  setState(() {
                    entry.noteController?.dispose();
                    entry.noteController = noteController.text.isNotEmpty
                        ? noteController
                        : null;
                    entry.point = MapPoint(
                      latitude: entry.point.latitude,
                      longitude: entry.point.longitude,
                      label: labelController.text.isEmpty
                          ? null
                          : labelController.text,
                      note: noteController.text.isEmpty
                          ? null
                          : noteController.text,
                    );
                  });
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  /// Kaydet
  Future<void> _save() async {
    if (_entries.isEmpty) {
      _showSnackBar('Lütfen harita üzerinde en az bir durak işaretleyin');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final finalPoints = _entries.map((e) {
        return MapPoint(
          latitude: e.point.latitude,
          longitude: e.point.longitude,
          label: e.point.label,
          note: e.note,
        );
      }).toList();

      await _recordService.saveRecord(
        points: finalPoints,
        title: _titleController.text.trim(),
        text: _textController.text.trim(),
        photoBase64: _recordPhotoBase64,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnackBar('Kayıt başarısız: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Haritayı Türkiye'ye sıfırla
  void _resetMapView() {
    _mapController.move(_turkeyCenter, _initialZoom);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Kayıt'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_entries.isNotEmpty || _textController.text.isNotEmpty) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Çıkmak istediğinize emin misiniz?'),
                  content:
                      const Text('Kaydedilmemiş değişiklikler silinecek.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Vazgeç'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text('Çık'),
                    ),
                  ],
                ),
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _resetMapView,
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: const Text('Türkiye'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Harita başlığı ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.map_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Haritaya tıklayarak durak ekleyin',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_entries.length}/10',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- OpenStreetMap Haritası ---
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _turkeyCenter,
                            initialZoom: _initialZoom,
                            minZoom: _minZoom,
                            maxZoom: _maxZoom,
                            onTap: _onMapTap,
                            onMapReady: () {
                              if (!_mapReady) {
                                _mapReady = true;
                                _animController.forward();
                              }
                            },
                          ),
                          children: [
                        TileLayer(
                          urlTemplate:
                              'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                          userAgentPackageName: 'com.iqb.flutter_app',
                        ),

                        // İşaretlenmiş duraklar
                        MarkerLayer(
                          markers: _entries.asMap().entries.map((e) {
                            final index = e.key;
                            final entry = e.value;
                            final lbl = entry.label;
                            final hasLabel = lbl != null && lbl.isNotEmpty;

                            return Marker(
                              point: LatLng(
                                entry.point.latitude,
                                entry.point.longitude,
                              ),
                              width: hasLabel ? 80 : 40,
                              height: hasLabel ? 56 : 44,
                              child: GestureDetector(
                                onTap: () => _editPointNote(index),
                                onLongPress: () => _removePoint(index),
                                child: ClipRect(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                    // Pin işareti
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade600,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                                alpha: 0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.push_pin_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    // Etiket (sadece varsa)
                                    if (hasLabel)
                                      Container(
                                        margin: const EdgeInsets.only(top: 3),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.15),
                                              blurRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          lbl,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    // Zoom butonları
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: Colors.white,
                            elevation: 2,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                final currentZoom = _mapController.camera.zoom;
                                _mapController.move(
                                  _mapController.camera.center,
                                  (currentZoom + 1).clamp(_minZoom, _maxZoom),
                                );
                              },
                              child: const SizedBox(
                                width: 36,
                                height: 36,
                                child: Icon(Icons.add_rounded, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Material(
                            color: Colors.white,
                            elevation: 2,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                final currentZoom = _mapController.camera.zoom;
                                _mapController.move(
                                  _mapController.camera.center,
                                  (currentZoom - 1).clamp(_minZoom, _maxZoom),
                                );
                              },
                              child: const SizedBox(
                                width: 36,
                                height: 36,
                                child: Icon(Icons.remove_rounded, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

          // --- Nokta chip listesi ---
          if (_entries.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _entries.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  final lbl = entry.label ?? 'Durak ${index + 1}';
                  final hasNote =
                      entry.note != null && entry.note!.isNotEmpty;
                  return InputChip(
                    avatar: Icon(
                      Icons.push_pin_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(lbl, style: const TextStyle(fontSize: 12)),
                        if (hasNote) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.notes_rounded,
                              size: 12, color: Colors.orange.shade700),
                        ],
                      ],
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _removePoint(index),
                    onPressed: () => _editPointNote(index),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),

          // --- Genel başlık ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Icon(Icons.title_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Genel Başlık',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextFormField(
              controller: _titleController,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Kayda bir başlık verin (opsiyonel)',
                prefixIcon: const Icon(Icons.edit_note_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // --- Genel not başlığı ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                Icon(Icons.notes_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Genel Not',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '$_charCount/2000',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _charCount > 1900
                        ? Colors.red
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // --- Genel not alanı + fotoğraf ---
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                children: [
                  // Genel not fotoğrafı
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final photo = await _pickPhoto();
                          if (photo != null) {
                            setState(() => _recordPhotoBase64 = photo);
                          }
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: _recordPhotoBase64 != null
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(7),
                                      child: buildPhotoImage(
                                        _recordPhotoBase64,
                                        fit: BoxFit.cover,
                                        placeholder: const Icon(Icons.broken_image,
                                            color: Colors.grey, size: 18),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo_outlined,
                                        size: 20, color: Colors.grey.shade500),
                                    Text('Fotoğraf',
                                        style: TextStyle(
                                            fontSize: 8,
                                            color: Colors.grey.shade500)),
                                  ],
                                ),
                        ),
                      ),
                      if (_recordPhotoBase64 != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () =>
                              setState(() => _recordPhotoBase64 = null),
                          child: const Text('Kaldır',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Metin alanı
                  SizedBox(
                    height: 120,
                    child: TextFormField(
                      controller: _textController,
                      focusNode: _textFocusNode,
                      maxLength: 2000,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Buraya genel notunuzu yazabilirsiniz...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      buildCounter: (context,
                          {required int currentLength,
                          required bool isFocused,
                          required int? maxLength}) {
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Kaydet butonu ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Kaydediliyor...' : 'Kaydet'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
