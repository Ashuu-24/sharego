import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/coach.dart';
import '../common/widgets.dart';

class TripManageScreen extends ConsumerStatefulWidget {
  const TripManageScreen({super.key});

  @override
  ConsumerState<TripManageScreen> createState() => _TripManageScreenState();
}

class _TripManageScreenState extends ConsumerState<TripManageScreen> {
  List<Map<String, dynamic>> trips = [];
  bool _loading = true;
  String? _error;

  final _fabKey = GlobalKey();
  final _listKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadTrips();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Coach.show(
        context,
        storageKey: 'has_seen_traveler_screen_guide',
        steps: [
          CoachStep(
            targetKey: _fabKey,
            title: 'Post your trip',
            body: 'Tap to add your upcoming flight.',
          ),
          CoachStep(
            targetKey: _listKey,
            title: 'Your trips',
            body: 'Manage the trips you have posted.',
          ),
        ],
      );
    });
  }

  Future<void> _loadTrips() async {
    setState(() { _loading = true; _error = null; });
    try {
      final service = ref.read(tripServiceProvider);
      final result = await service.listTrips(mine: true);
      if (mounted) setState(() { trips = result; _loading = false; });
    } catch (e) {
      if (mounted) {
        if (e is DioException && e.response?.statusCode == 401) {
          await ref.read(authStorageProvider).clear();
          if (context.mounted) {
            context.go('/auth/login');
            return;
          }
        }
        setState(() { _error = formatErrorMessage(e); _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onPressed: () => Coach.show(
              context,
              force: true,
              storageKey: 'has_seen_traveler_screen_guide',
              steps: [
                CoachStep(
                  targetKey: _fabKey,
                  title: 'Post your trip',
                  body: 'Tap to add your upcoming flight.',
                ),
                CoachStep(
                  targetKey: _listKey,
                  title: 'Your trips',
                  body: 'Manage the trips you have posted.',
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: _fabKey,
        onPressed: () async {
          await context.push('/trip/new/flight');
          _loadTrips(); // Refresh after creating a new trip.
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Trip'),
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: SkeletonList(items: 4, itemHeight: 100),
            )
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ErrorBanner(_error!),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _loadTrips, child: const Text('Retry')),
                    ],
                  ),
                )
              : trips.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadTrips,
                      child: ListView.separated(
                        key: _listKey,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: trips.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final trip = trips[index];
                          return _TripCard(
                            trip: trip,
                            onView: () => context.push('/trip/${trip['id']}'),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.onView,
  });

  final Map<String, dynamic> trip;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final origin = trip['origin_airport']?.toString() ?? '';
    final dest = trip['dest_airport']?.toString() ?? '';
    final route = '$origin → $dest';
    final date = trip['date']?.toString().split('T').first ?? '';
    final capacity = trip['capacity_kg']?.toString() ?? '-';
    final fee = trip['fee_pkr']?.toString() ?? '-';

    final airline = trip['airline']?.toString();
    final flightNum = trip['flight_number']?.toString();
    final hasFlightInfo = (airline != null && airline.isNotEmpty) ||
        (flightNum != null && flightNum.isNotEmpty);
    final flightLabel = [
      if (airline != null && airline.isNotEmpty) airline,
      if (flightNum != null && flightNum.isNotEmpty) flightNum,
    ].join(' ');
    final status = trip['status']?.toString() ?? 'pending_review';

    return InkWell(
      onTap: onView,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    route,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 4),
            Text(date, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (hasFlightInfo) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  flightLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                _Pill(text: 'Capacity: $capacity kg'),
                const SizedBox(width: 8),
                _Pill(text: 'Fee: PKR $fee/kg'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.flight_takeoff, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(child: Text(origin, style: theme.textTheme.bodySmall)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.flight_land, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(child: Text(dest, style: theme.textTheme.bodySmall)),
              ],
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'approved' => ('Approved', AppTheme.success),
      'rejected' => ('Rejected', Colors.red),
      _ => ('Pending', AppTheme.amber),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flight_takeoff, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text('No trips yet', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Add your travel plans to receive bookings.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push('/trip/new/flight'),
              child: const Text('Post a Trip'),
            ),
          ],
        ),
      ),
    );
  }
}
