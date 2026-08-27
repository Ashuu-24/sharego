import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_theme.dart';
import '../../core/kyc_error_handler.dart';
import '../../core/providers.dart';
import '../common/widgets.dart';

class ListingCreateScreen extends ConsumerStatefulWidget {
  const ListingCreateScreen({super.key});

  @override
  ConsumerState<ListingCreateScreen> createState() => _ListingCreateScreenState();
}

class _ListingCreateScreenState extends ConsumerState<ListingCreateScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController();

  String _selectedCategory = 'Electronics';
  final List<_PickedPhoto> _photos = [];
  bool _submitting = false;
  String? _error;
  double? _latitude;
  double? _longitude;
  bool _detectingLocation = false;

  final _picker = ImagePicker();
  static const _categories = ['Electronics', 'Fashion', 'Home', 'Sports', 'Books', 'Other'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _detectLocation(silent: true);
    });
  }

  Future<void> _pickImage() async {
    if (_photos.length >= 4) return;
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null && mounted) {
      // Read bytes immediately while the cached file still exists.
      final bytes = await picked.readAsBytes();
      setState(() => _photos.add(_PickedPhoto(path: picked.path, name: picked.name, bytes: bytes)));
    }
  }

  Future<void> _detectLocation({bool silent = false}) async {
    setState(() => _detectingLocation = true);
    try {
      final locationService = ref.read(locationServiceProvider);
      final position = await locationService.getCurrentPosition();
      if (position != null && mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          if (_locationCtrl.text.trim().isEmpty) {
            _locationCtrl.text = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
          }
        });
      } else if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not detect location. Please enter it manually.')),
        );
      }
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final priceStr = _priceCtrl.text.trim();
    final location = _locationCtrl.text.trim();
    final condition = _conditionCtrl.text.trim();

    if (title.isEmpty || desc.isEmpty || priceStr.isEmpty) {
      setState(() => _error = 'Title, description, and price are required.');
      return;
    }
    if (title.length < 3) {
      setState(() => _error = 'Title must be at least 3 characters.');
      return;
    }
    final price = double.tryParse(priceStr);
    if (price == null || price <= 0) {
      setState(() => _error = 'Enter a valid price.');
      return;
    }

    setState(() { _submitting = true; _error = null; });

    try {
      final profileService = ref.read(profileServiceProvider);
      final marketService = ref.read(marketplaceServiceProvider);

      // Upload photos first (using pre-read bytes to avoid stale cache paths).
      // ✅ Upload photos using file path (FIXED)
final List<String> photoPaths = [];

for (final photo in _photos) {
  final result = await profileService.uploadMediaBytes(
    photo.bytes,
    photo.name.trim().isNotEmpty ? photo.name : 'photo.jpg',
  );

  final path = result['path']?.toString() ?? result['url']?.toString();

  if (path == null || path.isEmpty) {
    throw Exception('Upload failed: no path returned');
  }

  photoPaths.add(path);
}

      // Create listing.
      await marketService.createListing(
        title: title,
        description: desc,
        askPrice: price,
        photosPaths: photoPaths,
        category: _selectedCategory,
        condition: condition.isNotEmpty ? condition : null,
        locationText: location.isNotEmpty ? location : null,
        latitude: _latitude,
        longitude: _longitude,
      );

      if (mounted) context.go('/market/new/success');
    } catch (e) {
      if (!mounted) return;
      if (isKycError(e)) {
        setState(() => _submitting = false);
        showKycRequiredDialog(context);
      } else {
        String errorMsg = e.toString().replaceFirst('Exception: ', '');
        if (e is DioException && e.response != null) {
          final data = e.response?.data;
          if (data is Map && data['detail'] != null) {
            errorMsg = data['detail'].toString();
          } else {
            errorMsg = 'Status ${e.response?.statusCode}: $data';
          }
        }
        setState(() { _error = errorMsg; _submitting = false; });
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _locationCtrl.dispose();
    _conditionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(elevation: 0, title: const Text('List product')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _StepBadge(text: '1/3 Photos'),
          _PhotoGrid(
            photos: _photos,
            onAdd: _pickImage,
            onRemove: (i) => setState(() => _photos.removeAt(i)),
          ),
          const SizedBox(height: 18),
          const _StepBadge(text: '2/3 Details'),
          _SectionCard(
            title: 'Listing info',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Field('Title', controller: _titleCtrl),
                _Field('Description', controller: _descCtrl, maxLines: 3),
                Row(
                  children: [
                    Expanded(child: _Field('Price (PKR)', controller: _priceCtrl, keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: _Field('Condition', controller: _conditionCtrl)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Category & location',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) { if (v != null) setState(() => _selectedCategory = v); },
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: _Field('Location', controller: _locationCtrl)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: IconButton(
                        onPressed: _detectingLocation ? null : _detectLocation,
                        icon: _detectingLocation
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                Icons.my_location,
                                color: _latitude != null ? AppTheme.primary : Colors.black45,
                              ),
                        tooltip: 'Detect location',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorBanner(_error!),
          ],
          const SizedBox(height: 22),
          LoadingButton(
            onPressed: _submit,
            label: 'Post listing',
            isLoading: _submitting,
          ),
        ],
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos, required this.onAdd, required this.onRemove});
  final List<_PickedPhoto> photos;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (i) {
        if (i < photos.length) {
          return Expanded(
            child: GestureDetector(
              onTap: () => onRemove(i),
              child: Container(
                height: 86,
                margin: EdgeInsets.only(right: i == 3 ? 0 : 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(photos[i].bytes, fit: BoxFit.cover),
                      const Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(Icons.close, size: 18, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return Expanded(
          child: GestureDetector(
            onTap: onAdd,
            child: Container(
              height: 86,
              margin: EdgeInsets.only(right: i == 3 ? 0 : 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E2EB)),
                color: const Color(0xFFF7F8FC),
              ),
              child: const Icon(Icons.add_a_photo_outlined, color: Colors.black45),
            ),
          ),
        );
      }),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E2EB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, {required this.controller, this.maxLines = 1, this.keyboardType});
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0E2EB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickedPhoto {
  const _PickedPhoto({required this.path, required this.name, required this.bytes});
  final String path;
  final String name;
  final Uint8List bytes;
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary)),
        ),
      ),
    );
  }
}
