import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _imagePicker = ImagePicker();

  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();

  DateTime? _birthDate;
  String? _photoBase64;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  // Orijinal değerler
  String _originalName = '';
  String _originalSurname = '';
  DateTime? _originalBirthDate;
  String? _originalPhotoBase64;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  bool get _hasChanges {
    return _nameController.text.trim() != _originalName ||
        _surnameController.text.trim() != _originalSurname ||
        _birthDate != _originalBirthDate ||
        _photoBase64 != _originalPhotoBase64;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final data = await _authService.getUserData(user.uid);
    if (!mounted) return;

    if (data != null) {
      _originalName = (data['name'] as String? ?? '').trim();
      _originalSurname = (data['surname'] as String? ?? '').trim();
      _originalPhotoBase64 = data['photoBase64'] as String?;

      _nameController.text = _originalName;
      _surnameController.text = _originalSurname;
      _photoBase64 = _originalPhotoBase64;

      final birthDateStr = data['birthDate'] as String?;
      if (birthDateStr != null) {
        _originalBirthDate = DateTime.tryParse(birthDateStr);
        _birthDate = _originalBirthDate;
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickAndUploadPhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 40,
      maxWidth: 200,
      maxHeight: 200,
    );

    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      // Dosyayı oku ve base64'e çevir
      final bytes = await File(picked.path).readAsBytes();
      final base64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      if (mounted) {
        setState(() {
          _photoBase64 = base64;
          _isUploadingPhoto = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraf okunamadı: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now.subtract(const Duration(days: 365 * 13)),
      helpText: 'Doğum Tarihi Seçin',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );
    if (picked != null && picked != _birthDate) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Herhangi bir değişiklik yapmadınız'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('Kullanıcı bulunamadı');

      // Profil bilgilerini güncelle
      await _authService.updateUserData(
        uid: user.uid,
        name: _nameController.text,
        surname: _surnameController.text,
        birthDate: _birthDate,
      );

      // Profil fotoğrafı değiştiyse kaydet
      if (_photoBase64 != _originalPhotoBase64) {
        if (_photoBase64 != null) {
          await _authService.saveProfilePhoto(
            uid: user.uid,
            base64: _photoBase64!,
          );
        } else {
          await _authService.deleteProfilePhoto(user.uid);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Hesap bilgileriniz güncellendi'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kaydetme hatası: ${e.message}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Beklenmeyen hata: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hesabım'),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Profil Fotoğrafı ──
                        Center(
                          child: GestureDetector(
                            onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                            child: Stack(
                              children: [
                                _buildProfileAvatar(theme),
                                // Kalem ikonu
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.colorScheme.surface,
                                        width: 2,
                                      ),
                                    ),
                                    child: _isUploadingPhoto
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.edit_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            _photoBase64 != null
                                ? 'Değiştirmek için kaleme tıklayın'
                                : 'Fotoğraf eklemek için tıklayın',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // E-posta (salt okunur)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              user?.email ?? '',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Ad
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Ad',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Ad gerekli' : null,
                        ),
                        const SizedBox(height: 20),

                        // Soyad
                        TextFormField(
                          controller: _surnameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Soyad',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Soyad gerekli' : null,
                        ),
                        const SizedBox(height: 20),

                        // Doğum tarihi
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Doğum Tarihi',
                              prefixIcon: Icon(Icons.cake_outlined),
                              suffixIcon: Icon(Icons.calendar_today_rounded),
                            ),
                            child: Text(
                              _birthDate != null
                                  ? '${_birthDate!.day.toString().padLeft(2, '0')}.${_birthDate!.month.toString().padLeft(2, '0')}.${_birthDate!.year}'
                                  : 'Seçiniz...',
                              style: TextStyle(
                                color: _birthDate != null
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurfaceVariant,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Kaydet butonu
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed:
                                (_isSaving || !_hasChanges) ? null : _save,
                            child: _isSaving
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Kaydet',
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildProfileAvatar(ThemeData theme) {
    const size = 100.0;

    if (_photoBase64 != null && _photoBase64!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 3,
          ),
        ),
        child: ClipOval(
          child: Image.memory(
            base64Decode(_photoBase64!.split(',').last),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildPlaceholder(theme, size),
          ),
        ),
      );
    }

    return _buildPlaceholder(theme, size);
  }

  Widget _buildPlaceholder(ThemeData theme, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 3,
        ),
      ),
      child: Icon(
        Icons.person_rounded,
        size: size * 0.5,
        color: theme.colorScheme.primary.withValues(alpha: 0.6),
      ),
    );
  }
}
