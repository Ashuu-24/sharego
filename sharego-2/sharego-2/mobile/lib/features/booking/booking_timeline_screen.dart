import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/widgets.dart';

class BookingTimelineScreen extends ConsumerStatefulWidget {
  const BookingTimelineScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<BookingTimelineScreen> createState() =>
      _BookingTimelineScreenState();
}

class _BookingTimelineScreenState extends ConsumerState<BookingTimelineScreen> {
  Map<String, dynamic>? _booking;
  List<Map<String, dynamic>> _updates = [];
  bool _loading = true;
  String? _error;
  int? _currentUserId;

  bool get _isTraveler {
    if (_currentUserId == null || _booking == null) return false;
    final tid = _booking!['traveler_id'];
    if (tid == null) return false;
    return (tid is int ? tid : int.tryParse(tid.toString())) == _currentUserId;
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final bookingId = int.tryParse(widget.id);
      if (bookingId == null) throw Exception('Invalid booking ID');
      final service = ref.read(featureAServiceProvider);
      final profileService = ref.read(profileServiceProvider);

      final results = await Future.wait([
        service.getBooking(bookingId),
        profileService.getMe(),
      ]);

      // Fetch updates separately so failure doesn't block main view
      List<Map<String, dynamic>> updates = [];
      try {
        updates = await service.listBookingUpdates(bookingId);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _booking = results[0];
          _currentUserId = results[1]['id'] as int?;
          _updates = updates;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = formatErrorMessage(e); _loading = false; });
    }
  }

  Future<void> _showReviewDialog(BuildContext ctx, Map<String, dynamic> b) async {
    int rating = 5;
    final commentCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: ctx,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Leave a Review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(
                  icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber),
                  onPressed: () => setDialogState(() => rating = i + 1),
                )),
              ),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(hintText: 'Add a comment (optional)'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      try {
        final profileService = ref.read(profileServiceProvider);
        await profileService.submitReview(
          targetType: 'booking',
          targetId: int.tryParse(widget.id) ?? 0,
          revieweeId: b['traveler_id'] ?? b['buyer_id'] ?? 0,
          rating: rating,
          comment: commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('Review submitted!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('Failed: ${formatErrorMessage(e)}')),
          );
        }
      }
    }
  }

  Future<void> _showPostUpdateDialog() async {
    String selectedType = 'picked_up';
    final noteCtrl = TextEditingController();
    final types = {
      'picked_up': 'Picked up item',
      'at_airport': 'At the airport',
      'in_transit': 'In transit / On flight',
      'arrived': 'Arrived in destination',
      'custom': 'Custom note',
    };

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Post Status Update'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Status', isDense: true),
                items: types.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedType = v ?? 'custom'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Note (optional)', isDense: true),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Post')),
          ],
        ),
      ),
    );

    if (result != true) return;
    try {
      final service = ref.read(featureAServiceProvider);
      await service.postBookingUpdate(
        int.parse(widget.id),
        updateType: selectedType,
        note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status update posted')));
      }
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${formatErrorMessage(e)}')));
      }
    }
  }

  static const _updateTypeLabels = {
    'picked_up': 'Picked Up Item',
    'at_airport': 'At Airport',
    'in_transit': 'In Transit',
    'arrived': 'Arrived in City',
    'custom': 'Traveler Note',
  };

  List<Map<String, String>> _buildTimeline(Map<String, dynamic> b) {
    final status = b['status']?.toString() ?? '';
    final amount = b['amount'];
    final amountStr = amount != null ? 'PKR ${NumberFormat('#,##0').format(amount)}' : 'Payment';
    final items = <Map<String, String>>[];

    items.add({'title': 'Booking Created', 'subtitle': 'Request submitted', 'icon': 'done'});

    if (['HOLD_PLACED', 'ACCEPTED', 'PICKUP_OK', 'DELIVERY_OK', 'RELEASED'].contains(status)) {
      items.add({'title': 'Payment Deducted', 'subtitle': '$amountStr held in escrow', 'icon': 'done'});
    }
    if (['ACCEPTED', 'PICKUP_OK', 'DELIVERY_OK', 'RELEASED'].contains(status)) {
      items.add({'title': 'Traveler Accepted', 'subtitle': 'Traveler confirmed the job', 'icon': 'done'});
    }

    // Interleave traveler status updates (only relevant between ACCEPTED and PICKUP_OK/DELIVERY_OK)
    for (final u in _updates) {
      final type = u['update_type']?.toString() ?? 'custom';
      final note = u['note']?.toString() ?? '';
      final label = _updateTypeLabels[type] ?? type.replaceAll('_', ' ');
      final ts = u['created_at']?.toString();
      final subtitle = note.isNotEmpty ? note : (ts != null ? timeAgo(ts) : '');
      items.add({'title': label, 'subtitle': subtitle, 'icon': 'update'});
    }

    if (['PICKUP_OK', 'DELIVERY_OK', 'RELEASED'].contains(status)) {
      items.add({'title': 'Pickup Verified', 'subtitle': 'OTP confirmed at pickup', 'icon': 'done'});
    }
    if (['DELIVERY_OK', 'RELEASED'].contains(status)) {
      items.add({'title': 'Delivery Verified', 'subtitle': 'OTP confirmed at delivery', 'icon': 'done'});
    }
    if (status == 'RELEASED') {
      items.add({'title': 'Payment Released', 'subtitle': '$amountStr sent to traveler', 'icon': 'done'});
    }
    if (status == 'CANCELLED') {
      final escrowStatus = b['escrow_status']?.toString() ?? '';
      final refundNote = escrowStatus == 'refunded' ? '$amountStr returned to wallet' : 'Awaiting admin refund';
      items.add({'title': 'Cancelled', 'subtitle': refundNote, 'icon': 'cancel'});
    }
    if (status == 'EXPIRED') {
      items.add({'title': 'Expired', 'subtitle': 'Booking expired — contact support for refund', 'icon': 'cancel'});
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Booking ${widget.id}')),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: SkeletonList(items: 5, itemHeight: 60),
        ),
      );
    }
    if (_error != null || _booking == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Booking ${widget.id}')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ErrorBanner(_error ?? 'Booking not found'),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _loadAll, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final b = _booking!;
    final status = b['status']?.toString() ?? '';
    final timeline = _buildTimeline(b);

    return Scaffold(
      appBar: AppBar(
        title: Text('Booking #${widget.id}'),
        actions: [
          TextButton(
            onPressed: () => context.push('/audit/report/new'),
            child: Text('Report Issue', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Status', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                StatusPill(status),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Trip ID', value: '#${b['trip_id']}'),
            _InfoRow(label: 'Request ID', value: '#${b['request_id']}'),
            if (b['escrow_status'] != null)
              _InfoRow(
                label: 'Escrow',
                value: '${(b['escrow_status'] as String?)?.toUpperCase() ?? '-'} — PKR ${b['amount'] != null ? NumberFormat('#,##0').format(b['amount']) : '-'}',
              ),
            if (b['seal_id'] != null)
              _InfoRow(label: 'Seal ID', value: b['seal_id'].toString()),
            const SizedBox(height: 16),
            Text('Timeline', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: timeline.length,
                itemBuilder: (context, i) {
                  final e = timeline[i];
                  final iconType = e['icon'] ?? 'done';
                  final isLast = i == timeline.length - 1;
                  final Color dotColor;
                  if (iconType == 'done') {
                    dotColor = AppTheme.success;
                  } else if (iconType == 'update') {
                    dotColor = AppTheme.primary;
                  } else {
                    dotColor = AppTheme.danger;
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 32,
                          child: Column(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: dotColor,
                                  shape: iconType == 'update' ? BoxShape.rectangle : BoxShape.circle,
                                  borderRadius: iconType == 'update' ? BorderRadius.circular(3) : null,
                                  border: Border.all(color: dotColor.withValues(alpha: 0.3), width: 3),
                                ),
                              ),
                              if (!isLast)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: dotColor.withValues(alpha: 0.3),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e['title'] ?? '',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: iconType == 'update' ? AppTheme.primary : null,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(e['subtitle'] ?? '', style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Action buttons
            const SizedBox(height: 12),
            Row(
              children: [
                if (['ACCEPTED'].contains(status))
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.push('/booking/${widget.id}/pickup-otp'),
                      child: const Text('Pickup OTP'),
                    ),
                  ),
                if (['ACCEPTED'].contains(status))
                  const SizedBox(width: 10),
                if (['PICKUP_OK'].contains(status))
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.push('/booking/${widget.id}/delivery-otp'),
                      child: const Text('Delivery OTP'),
                    ),
                  ),
              ],
            ),

            // Post status update (traveler only, active bookings)
            if (_isTraveler && ['ACCEPTED', 'PICKUP_OK'].contains(status)) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.update),
                  label: const Text('Post Status Update'),
                  onPressed: _showPostUpdateDialog,
                ),
              ),
            ],

            // Chat with counterparty
            if (!['CANCELLED', 'EXPIRED'].contains(status)) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text('Chat with ${_isTraveler ? "Buyer" : "Traveler"}'),
                  onPressed: () {
                    final peerId = _isTraveler ? b['buyer_id'] : b['traveler_id'];
                    context.push('/chat/$peerId', extra: {'booking_id': int.tryParse(widget.id)});
                  },
                ),
              ),
            ],

            if (status == 'RELEASED') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.star_outline),
                  label: const Text('Leave a Review'),
                  onPressed: () => _showReviewDialog(context, b),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
