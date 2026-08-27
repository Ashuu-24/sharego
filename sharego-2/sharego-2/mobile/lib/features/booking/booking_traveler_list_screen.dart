import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/widgets.dart';
import 'booking_draft.dart';

class TravelerListScreen extends ConsumerStatefulWidget {
  const TravelerListScreen({super.key});

  @override
  ConsumerState<TravelerListScreen> createState() => _TravelerListScreenState();
}

class _TravelerListScreenState extends ConsumerState<TravelerListScreen> {
  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ref.read(tripServiceProvider).listTrips(),
        ref.read(profileServiceProvider).getMe(),
      ]);
      final allTrips = results[0] as List<Map<String, dynamic>>;
      final myId = (results[1] as Map<String, dynamic>)['id'];
      // Filter out the current user's own trips
      final filtered = allTrips.where((t) => t['user_id'] != myId).toList();
      if (mounted) setState(() { _trips = filtered; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: const Text('Select Traveler'),
        centerTitle: true,
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: SkeletonList(items: 4, itemHeight: 80),
            )
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ErrorBanner(_error!),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _loadTrips, child: const Text('Retry')),
                    ],
                  ),
                )
              : _trips.isEmpty
                  ? const EmptyState(
                      icon: Icons.flight_takeoff,
                      title: 'No travelers available',
                      subtitle: 'Check back later for new travelers',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemCount: _trips.length,
                      itemBuilder: (context, i) {
                        final t = _trips[i];
                        final origin = t['origin_airport']?.toString() ?? '';
                        final dest = t['dest_airport']?.toString() ?? '';
                        final capacity = t['capacity_kg']?.toString() ?? '-';
                        final fee = t['fee_pkr']?.toString() ?? '-';
                        final tripId = t['id']?.toString() ?? '';
                        final airline = t['airline']?.toString() ?? '';
                        final flightNumber = t['flight_number']?.toString() ?? '';

                        return _TravelerCard(
                          name: t['traveler_name']?.toString() ?? 'Traveler #${t['user_id'] ?? tripId}',
                          rating: (t['traveler_rating'] as num?)?.toDouble(),
                          route: '$origin → $dest',
                          capacity: '$capacity kg',
                          rate: fee,
                          airline: airline,
                          flightNumber: flightNumber,
                          onTap: () {
                            ref.read(bookingDraftProvider.notifier).selectTrip(tripId);
                            context.push('/book/traveler/$tripId');
                          },
                        );
                      },
                    ),
    );
  }
}

class _TravelerCard extends StatelessWidget {
  const _TravelerCard({
    required this.name,
    required this.route,
    required this.capacity,
    required this.rate,
    required this.onTap,
    this.airline = '',
    this.flightNumber = '',
    this.rating,
  });

  final String name;
  final String route;
  final String capacity;
  final String rate;
  final String airline;
  final String flightNumber;
  final double? rating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.flight_takeoff, color: theme.colorScheme.onPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface))),
                        if (rating != null && rating! > 0) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star, size: 13, color: Color(0xFFFFC107)),
                          const SizedBox(width: 2),
                          Text(rating!.toStringAsFixed(1), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(route, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                    if (flightNumber.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.flight, size: 13, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '${airline.isNotEmpty ? '$airline ' : ''}$flightNumber',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Pill(text: 'Capacity $capacity'),
                        const SizedBox(width: 6),
                        _Pill(text: 'Fee PKR $rate/kg'),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface)),
    );
  }
}
