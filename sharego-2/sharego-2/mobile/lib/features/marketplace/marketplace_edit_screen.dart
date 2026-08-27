import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/widgets.dart';

class ListingEditScreen extends ConsumerStatefulWidget {
  const ListingEditScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ListingEditScreen> createState() => _ListingEditScreenState();
}

class _ListingEditScreenState extends ConsumerState<ListingEditScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController();

  String _selectedCategory = 'Electronics';
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _fetchError;

  static const _categories = ['Electronics', 'Fashion', 'Home', 'Sports', 'Books', 'Other'];

  @override
  void initState() {
    super.initState();
    _fetchListing();
  }

  Future<void> _fetchListing() async {
    try {
      final service = ref.read(marketplaceServiceProvider);
      final listing = await service.getListing(int.parse(widget.id));
      if (mounted) {
        _titleCtrl.text = listing['title']?.toString() ?? '';
        _descCtrl.text = listing['description']?.toString() ?? '';
        final price = listing['ask_price'] ?? listing['price'];
        _priceCtrl.text = price != null ? price.toString() : '';
        _locationCtrl.text = listing['location_text']?.toString() ?? '';
        _conditionCtrl.text = listing['condition']?.toString() ?? '';
        final cat = listing['category']?.toString() ?? '';
        if (_categories.contains(cat)) {
          _selectedCategory = cat;
        }
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fetchError = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
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
      final service = ref.read(marketplaceServiceProvider);
      await service.updateListing(
        int.parse(widget.id),
        title: title,
        description: desc,
        askPrice: price,
        category: _selectedCategory,
        condition: condition.isNotEmpty ? condition : null,
        locationText: location.isNotEmpty ? location : null,
      );

      if (mounted) context.pop(true);
    } catch (e) {
      if (!mounted) return;
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
      appBar: AppBar(elevation: 0, title: const Text('Edit listing')),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: SkeletonList(items: 3, itemHeight: 60),
            )
          : _fetchError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ErrorBanner(_fetchError!),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() { _loading = true; _fetchError = null; });
                          _fetchListing();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
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
                          _Field('Location', controller: _locationCtrl),
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
                      label: 'Save changes',
                      isLoading: _submitting,
                    ),
                  ],
                ),
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
