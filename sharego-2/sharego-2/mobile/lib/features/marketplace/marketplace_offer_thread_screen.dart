import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/widgets.dart';

class OfferThreadScreen extends ConsumerStatefulWidget {
  const OfferThreadScreen({super.key, required this.listingId});
  final String listingId;

  @override
  ConsumerState<OfferThreadScreen> createState() => _OfferThreadScreenState();
}

class _OfferThreadScreenState extends ConsumerState<OfferThreadScreen> {
  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;
  String? _error;

  final _amountCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _sending = false;

  int? _currentUserId;
  int? _sellerId;
  bool get _isSeller => _currentUserId != null && _currentUserId == _sellerId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.wait([_loadIdentity(), _fetchOffers()]);
  }

  Future<void> _loadIdentity() async {
    try {
      final profile = await ref.read(profileServiceProvider).getMe();
      final listing = await ref.read(marketplaceServiceProvider).getListing(int.parse(widget.listingId));
      if (mounted) {
        setState(() {
          _currentUserId = profile['id'] as int?;
          _sellerId = listing['seller_id'] as int?;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchOffers() async {
    try {
      final service = ref.read(marketplaceServiceProvider);
      final data = await service.listOffers(int.parse(widget.listingId));
      if (mounted) setState(() { _offers = data; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() { _error = _extractError(e); _loading = false; });
      }
    }
  }

  Future<void> _reload() async {
    setState(() { _loading = true; _error = null; });
    await _fetchOffers();
  }

  String _extractError(Object e) {
    String msg = e.toString().replaceFirst('Exception: ', '');
    if (e is DioException && e.response?.data is Map) {
      msg = e.response!.data['detail']?.toString() ?? msg;
    }
    return msg;
  }

  // ── Seller actions ──────────────────────────────────

  Future<void> _acceptOffer(int offerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept Offer'),
        content: const Text('Are you sure you want to accept this offer? Other pending offers will be declined.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Accept')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(marketplaceServiceProvider).acceptOffer(offerId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer accepted')));
      await _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_extractError(e))));
    }
  }

  Future<void> _declineOffer(int offerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Offer'),
        content: const Text('Are you sure you want to decline this offer?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(marketplaceServiceProvider).declineOffer(offerId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer declined')));
      await _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_extractError(e))));
    }
  }

  Future<void> _showCounterDialog(int offerId) async {
    final counterAmountCtrl = TextEditingController();
    final counterMsgCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Counter Offer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: counterAmountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Your counter amount (PKR)', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: counterMsgCtrl,
              decoration: const InputDecoration(labelText: 'Message (optional)', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send Counter')),
        ],
      ),
    );
    if (result != true) return;
    final amount = double.tryParse(counterAmountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    try {
      final msg = counterMsgCtrl.text.trim();
      await ref.read(marketplaceServiceProvider).counterOffer(offerId, amount: amount, message: msg.isNotEmpty ? msg : null);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Counter offer sent')));
      await _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_extractError(e))));
    }
  }

  // ── Buyer actions ───────────────────────────────────

  Future<void> _withdrawOffer(int offerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Offer'),
        content: const Text('Are you sure you want to withdraw this offer?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Withdraw')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(marketplaceServiceProvider).withdrawOffer(offerId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer withdrawn')));
      await _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_extractError(e))));
    }
  }

  Future<void> _sendOffer() async {
    final amountStr = _amountCtrl.text.trim();
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final service = ref.read(marketplaceServiceProvider);
      final msg = _messageCtrl.text.trim();
      await service.sendOffer(
        listingId: int.parse(widget.listingId),
        amount: amount,
        message: msg.isNotEmpty ? msg : null,
      );
      _amountCtrl.clear();
      _messageCtrl.clear();
      setState(() { _sending = false; });
      await _reload();
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_extractError(e))),
        );
      }
    }
  }

  bool _isActionable(String status) {
    final s = status.toUpperCase();
    return s == 'SENT' || s == 'COUNTERED';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        title: Text('Offers • ${widget.listingId}'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DisclaimerBanner(),
          ),
          Expanded(child: _buildBody()),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SkeletonList(items: 3, itemHeight: 80),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ErrorBanner(_error!),
            const SizedBox(height: 12),
            TextButton(onPressed: _reload, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_offers.isEmpty) {
      return EmptyState(
        icon: Icons.local_offer_outlined,
        title: 'No offers yet',
        subtitle: _isSeller ? 'No offers received yet.' : 'Be the first to send an offer!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      itemCount: _offers.length,
      itemBuilder: (context, i) {
        final o = _offers[i];
        final status = o['status']?.toString() ?? '';
        final isMine = o['is_mine'] == true;
        final amount = o['amount'] ?? o['offer_amount'];
        final amountStr = amount != null ? 'PKR $amount' : '';
        final message = o['message']?.toString() ?? '';
        final byName = o['buyer_name']?.toString() ?? o['by']?.toString() ?? '';
        final createdAt = timeAgo(o['created_at']?.toString());
        final offerId = o['id'] as int? ?? 0;

        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
            decoration: BoxDecoration(
              color: isMine ? AppTheme.primary.withValues(alpha: 0.1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E2EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusPill(
                      status,
                      tone: status.toLowerCase().contains('accept')
                          ? StatusTone.success
                          : status.toLowerCase().contains('decline') || status.toLowerCase().contains('withdrawn')
                              ? StatusTone.danger
                              : StatusTone.info,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(createdAt, style: const TextStyle(fontSize: 11, color: Colors.black54), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(amountStr, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(message, style: const TextStyle(fontSize: 13)),
                ],
                const SizedBox(height: 2),
                Text(byName, style: const TextStyle(fontSize: 12, color: Colors.black54)),

                // Seller action buttons
                if (_isSeller && _isActionable(status)) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () => _acceptOffer(offerId),
                          child: const Text('Accept'),
                        ),
                      ),
                      SizedBox(
                        height: 32,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () => _declineOffer(offerId),
                          child: const Text('Decline'),
                        ),
                      ),
                      SizedBox(
                        height: 32,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.amber.shade800,
                            side: BorderSide(color: Colors.amber.shade800),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () => _showCounterDialog(offerId),
                          child: const Text('Counter'),
                        ),
                      ),
                    ],
                  ),
                ],

                // Buyer withdraw button
                if (!_isSeller && isMine && _isActionable(status)) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => _withdrawOffer(offerId),
                      child: const Text('Withdraw'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComposer() {
    // Seller sees info bar instead of offer form
    if (_isSeller) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You are the seller. Use the buttons above to respond to offers.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/audit/report/new'),
                child: const Text('Report'),
              ),
            ],
          ),
        ),
      );
    }

    // Buyer sees the send-offer form
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Offer amount (PKR)',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 120,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _sendOffer,
                    child: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Send'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageCtrl,
              decoration: InputDecoration(
                hintText: 'Message (optional)',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/audit/report/new'),
                child: const Text('Report issue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
