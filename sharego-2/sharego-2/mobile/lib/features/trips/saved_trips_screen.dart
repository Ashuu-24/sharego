import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';

class SavedTripsScreen extends ConsumerStatefulWidget {
  const SavedTripsScreen({super.key});

  @override
  ConsumerState<SavedTripsScreen> createState() => _SavedTripsScreenState();
}

class _SavedTripsScreenState extends ConsumerState<SavedTripsScreen> {
  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedTrips();
  }

  Future<void> _loadSavedTrips() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final savedTrips = ref.read(savedTripsServiceProvider);
      final tripService = ref.read(tripServiceProvider);
      final ids = savedTrips.savedIds;

      if (ids.isEmpty) {
        if (mounted) setState(() { _trips = []; _loading = false; });
        return;
      }

      final results = <Map<String, dynamic>>[];
      for (final id in ids) {
        try {
          final trip = await tripService.getTrip(id);
          results.add(trip);
        } catch (_) {
          // Trip may have been deleted — remove from saved
          await savedTrips.toggle(id);
        }
      }

      if (mounted) setState(() { _trips = results; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final savedTrips = ref.read(savedTripsServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Trips'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _loadSavedTrips, child: const Text('Retry')),
                    ],
                  ),
                )
              : _trips.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bookmark_border, size: 64, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text(
                            'No saved trips yet',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap the bookmark icon on any trip to save it here.',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSavedTrips,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _trips.length,
                        itemBuilder: (context, i) {
                          final t = _trips[i];
                          final id = t['id'] as int? ?? 0;
                          final origin = t['origin_airport']?.toString() ?? '';
                          final dest = t['dest_airport']?.toString() ?? '';
                          final date = t['date']?.toString() ?? '';
                          final capacityKg = t['capacity_kg']?.toString() ?? '-';
                          final feePkr = t['fee_pkr']?.toString() ?? '-';
                          final airline = t['airline']?.toString() ?? '';
                          final flightNumber = t['flight_number']?.toString() ?? '';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GestureDetector(
                              onTap: () => context.push('/book/traveler/$id'),
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
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.flight_takeoff, color: AppTheme.primary, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$origin → $dest',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            date,
                                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                          ),
                                          if (flightNumber.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              '${airline.isNotEmpty ? '$airline ' : ''}$flightNumber',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary),
                                            ),
                                          ],
                                          const SizedBox(height: 3),
                                          Text(
                                            '$capacityKg kg  •  PKR $feePkr/kg',
                                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () async {
                                        await savedTrips.toggle(id);
                                        setState(() {
                                          _trips.removeAt(i);
                                        });
                                      },
                                      child: const Icon(Icons.bookmark, size: 22, color: AppTheme.primary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
