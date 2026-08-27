import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/widgets.dart';

class MarkSoldScreen extends ConsumerStatefulWidget {
  const MarkSoldScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<MarkSoldScreen> createState() => _MarkSoldScreenState();
}

class _MarkSoldScreenState extends ConsumerState<MarkSoldScreen> {
  final _noteCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _done = false;

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    try {
      final service = ref.read(marketplaceServiceProvider);
      await service.markSold(
        int.parse(widget.id),
        note: _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
      );
      if (mounted) setState(() { _done = true; _submitting = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _submitting = false; });
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(elevation: 0, title: const Text('Mark as Sold')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: _done ? _buildSuccess() : _buildForm(),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sell, color: AppTheme.success, size: 64),
          const SizedBox(height: 16),
          const Text('Listing marked as sold!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('This listing is now closed.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => context.go('/market'),
              child: const Text('Back to Marketplace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Listing #${widget.id}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        const Text(
          'This action is irreversible. Once marked as sold, the listing will be permanently closed and all pending offers will be declined.',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _noteCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Note (optional)',
            hintText: 'e.g. Sold to buyer for agreed price',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          ErrorBanner(_error!),
        ],
        const Spacer(),
        LoadingButton(
          onPressed: _submit,
          label: 'Confirm — Mark as Sold',
          isLoading: _submitting,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.danger,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
