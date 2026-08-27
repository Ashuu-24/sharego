import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/widgets.dart';
import 'flight_tracking_card.dart';

class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  Map<String, dynamic>? _trip;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _bookings = [];
  bool _bookingsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    final tripId = int.tryParse(widget.id);
    if (tripId == null) {
      setState(() { _error = 'Invalid trip ID'; _loading = false; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ref.read(tripServiceProvider).getTrip(tripId);
      if (mounted) {
        setState(() { _trip = result; _loading = false; });
        _loadBookings();
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = formatErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadBookings() async {
    final tripId = int.tryParse(widget.id);
    if (tripId == null) return;
    setState(() => _bookingsLoading = true);
    try {
      final result = await ref.read(featureAServiceProvider).listBookingsForTrip(tripId);
      if (mounted) setState(() { _bookings = result; _bookingsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _bookingsLoading = false);
    }
  }

  Future<void> _acceptBooking(int bookingId) async {
    try {
      await ref.read(featureAServiceProvider).acceptBooking(bookingId);
      _loadBookings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept: ${formatErrorMessage(e)}')),
        );
      }
    }
  }

  Future<void> _declineBooking(int bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline booking?'),
        content: const Text('Are you sure you want to decline this booking?'),
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
      await ref.read(featureAServiceProvider).declineBooking(bookingId);
      _loadBookings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline: ${formatErrorMessage(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tripId = int.tryParse(widget.id);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text('Trip ${widget.id}'),
        centerTitle: true,
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: SkeletonList(items: 3, itemHeight: 80),
            )
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ErrorBanner(_error!),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _loadTrip, child: const Text('Retry')),
                    ],
                  ),
                )
              : _buildContent(theme, tripId),
    );
  }

  Widget _buildContent(ThemeData theme, int? tripId) {
    final trip = _trip!;
    final origin = trip['origin_airport']?.toString() ?? '';
    final dest = trip['dest_airport']?.toString() ?? '';
    final date = trip['date']?.toString().split('T').first ?? '';
    final capacity = trip['capacity_kg']?.toString() ?? '-';
    final fee = trip['fee_pkr']?.toString() ?? '-';
    final airline = trip['airline']?.toString();
    final flightNumber = trip['flight_number']?.toString();

    String dateFormatted = date;
    final parsedDate = DateTime.tryParse(trip['date']?.toString() ?? '');
    if (parsedDate != null) {
      dateFormatted = DateFormat('dd/MM/yyyy').format(parsedDate);
    }

    final hasFlightInfo = flightNumber != null && flightNumber.isNotEmpty;
    final airlineDisplay = airline != null && airline.isNotEmpty ? airline : null;
    final flightLabel = [
      if (airlineDisplay != null) airlineDisplay,
      if (hasFlightInfo) flightNumber,
    ].join(' ');
    final status = trip['status']?.toString() ?? 'pending_review';
    final rejectReason = trip['reject_reason']?.toString();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (status != 'approved') ...[
          _TripStatusBanner(status: status, rejectReason: rejectReason),
          const SizedBox(height: 12),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$origin → $dest',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                flightLabel.isNotEmpty
                    ? '$dateFormatted | $flightLabel'
                    : dateFormatted,
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Text(
                'Capacity: $capacity kg | Rate: PKR $fee per kg',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
              ),
            ],
          ),
        ),

        // Flight tracking card (only if flight number is present).
        if (hasFlightInfo && tripId != null)
          FlightTrackingCard(tripId: tripId),

        const SizedBox(height: 14),
        Text(
          'Bookings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),

        if (_bookingsLoading)
          const SkeletonList(items: 2, itemHeight: 80)
        else if (_bookings.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: _cardDecoration(context),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No bookings yet for this trip.',
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          )
        else
          ..._bookings.map((b) => _BookingCard(
            booking: b,
            onAccept: () => _acceptBooking(b['id'] as int),
            onDecline: () => _declineBooking(b['id'] as int),
          )),

        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {},
                child: const Text(
                  'Pause Trip',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => context.push('/audit/report/new'),
                child: const Text(
                  'Report Issue',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, this.onAccept, this.onDecline});
  final Map<String, dynamic> booking;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final status = booking['status']?.toString() ?? '';
    final amount = booking['amount'];
    final currency = booking['currency']?.toString() ?? 'PKR';
    final buyerName = booking['buyer_name']?.toString() ?? 'Buyer';
    final productName = booking['product_name']?.toString() ?? '';
    final waybill = booking['waybill']?.toString() ?? '';
    final isPending = status == 'HOLD_PLACED';

    final bookingId = booking['id'];
    return GestureDetector(
      onTap: bookingId != null ? () => context.push('/booking/$bookingId/timeline') : null,
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  productName.isNotEmpty ? productName : 'Booking #${booking['id']}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              StatusPill(status),
            ],
          ),
          const SizedBox(height: 6),
          Text('From: $buyerName', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (amount != null)
            Text('$currency ${amount.toString()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary)),
          if (waybill.isNotEmpty)
            Text('Waybill: $waybill', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (isPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: onDecline,
                    child: const Text('Decline', style: TextStyle(color: Colors.red)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: onAccept,
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
    );
  }
}

class _TripStatusBanner extends StatelessWidget {
  const _TripStatusBanner({required this.status, this.rejectReason});
  final String status;
  final String? rejectReason;

  @override
  Widget build(BuildContext context) {
    final isRejected = status == 'rejected';
    final color = isRejected ? Colors.red : AppTheme.amber;
    final icon = isRejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded;
    final title = isRejected ? 'Trip Rejected' : 'Pending Review';
    final subtitle = isRejected
        ? (rejectReason ?? 'Your trip was not approved by the admin.')
        : 'Your trip is under review. You\'ll be notified once approved.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
  color: Theme.of(context).colorScheme.surface,
  borderRadius: const BorderRadius.all(Radius.circular(12)),
  border: Border.all(color: Theme.of(context).dividerColor),
);
