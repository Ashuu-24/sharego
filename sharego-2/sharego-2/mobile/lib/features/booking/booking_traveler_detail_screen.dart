import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/coach.dart';
import '../common/widgets.dart';
import '../trips/flight_tracking_card.dart';
import 'booking_draft.dart';

class TravelerDetailScreen extends ConsumerStatefulWidget {
  const TravelerDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<TravelerDetailScreen> createState() =>
      _TravelerDetailScreenState();
}

class _TravelerDetailScreenState extends ConsumerState<TravelerDetailScreen> {
  Map<String, dynamic>? _trip;
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;
  String? _error;

  final _requestKey = GlobalKey();
  final _infoKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final tripData =
          await ref.read(tripServiceProvider).getTrip(int.parse(widget.id));
      List<Map<String, dynamic>> reviewData = [];
      final userId = tripData['user_id'];
      if (userId != null) {
        try {
          reviewData = await ref
              .read(profileServiceProvider)
              .getReviews(revieweeId: userId as int);
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _trip = tripData;
          _reviews = reviewData;
          _loading = false;
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Coach.show(
          context,
          storageKey: 'has_seen_traveler_detail_guide',
          steps: [
            CoachStep(
              targetKey: _infoKey,
              title: 'Trip details',
              body: 'Check route, date and capacity here.',
            ),
            CoachStep(
              targetKey: _requestKey,
              title: 'Send request',
              body: 'Tap to book this traveler.',
            ),
          ],
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  String _formatDate(String? raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('hh:mm a, dd/MM/yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: SkeletonList(items: 4, itemHeight: 60),
        ),
      );
    }

    if (_error != null || _trip == null) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface),
            onPressed: () => context.pop(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: ErrorBanner(_error ?? 'Trip not found'),
        ),
      );
    }

    final trip = _trip!;
    final origin = trip['origin_airport']?.toString() ?? '';
    final dest = trip['dest_airport']?.toString() ?? '';
    final capacityKg = trip['capacity_kg']?.toString() ?? '-';
    final feePkr = trip['fee_pkr']?.toString() ?? '-';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: theme.colorScheme.onSurface),
            onPressed: () {},
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                key: _infoKey,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppTheme.primary,
                          child: Icon(Icons.person,
                              color: theme.colorScheme.onPrimary, size: 30),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip['traveler_name']?.toString() ?? 'Traveler #${trip['user_id'] ?? trip['id']}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              if (trip['traveler_rating'] != null && (trip['traveler_rating'] as num) > 0) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.star, size: 14, color: Color(0xFFFFC107)),
                                    const SizedBox(width: 2),
                                    Text(
                                      (trip['traveler_rating'] as num).toStringAsFixed(1),
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 2),
                              Text(
                                '$origin → $dest',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final savedTrips = ref.read(savedTripsServiceProvider);
                            await savedTrips.toggle(int.tryParse(widget.id) ?? 0);
                            setState(() {});
                          },
                          child: Icon(
                            ref.read(savedTripsServiceProvider).isSaved(int.tryParse(widget.id) ?? 0)
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: ref.read(savedTripsServiceProvider).isSaved(int.tryParse(widget.id) ?? 0)
                                ? AppTheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(label: 'From:', value: origin),
                    _DetailRow(label: 'To:', value: dest),
                    _DetailRow(
                      label: 'Date:',
                      value: _formatDate(trip['date']?.toString()),
                    ),
                    _DetailRow(label: 'Capacity:', value: '$capacityKg kg'),
                    _DetailRow(label: 'Rate per kg:', value: 'Rs. $feePkr'),
                    if ((trip['airline']?.toString() ?? '').isNotEmpty)
                      _DetailRow(label: 'Airline:', value: trip['airline'].toString()),
                    if ((trip['flight_number']?.toString() ?? '').isNotEmpty)
                      _DetailRow(label: 'Flight:', value: trip['flight_number'].toString()),
                  ],
                ),
              ),
              if ((trip['flight_number']?.toString() ?? '').isNotEmpty)
                FlightTrackingCard(tripId: int.parse(widget.id)),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  'Reviews',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (_reviews.isEmpty)
                const EmptyState(
                  icon: Icons.rate_review,
                  title: 'No reviews yet',
                )
              else
                ..._reviews.take(5).map((r) => _ReviewCard(review: r)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: _requestKey,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    ref
                        .read(bookingDraftProvider.notifier)
                        .selectTrip(widget.id);
                    context.push('/book/details');
                  },
                  child: const Text(
                    'Book Now',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final rating = (review['rating'] as num?)?.toInt() ?? 5;
    final comment = review['comment']?.toString() ?? '';
    final reviewerEmail = review['reviewer_name']?.toString() ?? review['reviewer_email']?.toString() ?? 'User';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.6),
                  child: Icon(Icons.person, color: Theme.of(context).colorScheme.onPrimary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    reviewerEmail,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  size: 14,
                  color: const Color(0xFFFFC107),
                ),
              ),
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                comment,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
