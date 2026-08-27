import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/airport_search_field.dart';
import '../common/coach.dart';
import '../common/widgets.dart';
import 'booking_draft.dart';

class BookingDateScreen extends ConsumerStatefulWidget {
  const BookingDateScreen({super.key});

  @override
  ConsumerState<BookingDateScreen> createState() => _BookingDateScreenState();
}

class _BookingDateScreenState extends ConsumerState<BookingDateScreen> {
  String _from = 'LHE';
  String _to = 'RUH';
  double _weight = 5;
  bool _locationDetected = false;

  late DateTime _selectedDate;

  List<Map<String, dynamic>> _trips = [];
  bool _tripsLoading = true;
  String? _tripsError;

  Timer? _debounceTimer;

  final _dateKey = GlobalKey();
  final _fromKey = GlobalKey();
  final _toKey = GlobalKey();
  final _weightKey = GlobalKey();
  final _travelerCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final draft = ref.read(bookingDraftProvider);
    _from = draft.fromCity;
    _to = draft.toCity;
    _weight = draft.weightKg;
    _selectedDate = DateTime(
      draft.selectedDate.year,
      draft.selectedDate.month,
      draft.selectedDate.day,
    );
    _searchTrips();
    _detectLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Coach.show(
        context,
        storageKey: 'has_seen_book_screen_guide',
        steps: [
          CoachStep(
            targetKey: _fromKey,
            title: 'Choose route',
            body: 'Search and select your origin airport.',
          ),
          CoachStep(
            targetKey: _toKey,
            title: 'Pick destination',
            body: 'Search where the item should go.',
          ),
          CoachStep(
            targetKey: _dateKey,
            title: 'Travel date',
            body: 'Pick when the traveler is flying.',
          ),
          CoachStep(
            targetKey: _weightKey,
            title: 'Weight & budget',
            body: 'Set item weight in kg for matching.',
          ),
          CoachStep(
            targetKey: _travelerCardKey,
            title: 'Traveler options',
            body: 'Tap a traveler to send your request.',
          ),
        ],
      );
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _searchTrips() async {
    setState(() {
      _tripsLoading = true;
      _tripsError = null;
    });
    try {
      final result = await ref.read(tripServiceProvider).searchTrips(
        origin: _from,
        dest: _to,
        minCapacity: _weight,
        dateFrom: _selectedDate,
        dateTo: _selectedDate.add(const Duration(days: 3)),
      );
      if (mounted) setState(() { _trips = result; _tripsLoading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _tripsError = e.toString().replaceFirst('Exception: ', '');
        _tripsLoading = false;
      });
    }
  }

  void _debouncedSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), _searchTrips);
  }

  Future<void> _detectLocation() async {
    final locationService = ref.read(locationServiceProvider);
    final position = await locationService.getCurrentPosition();
    if (position == null || !mounted) return;

    final airportRepo = ref.read(airportRepositoryProvider);
    final nearest = airportRepo.nearestTo(position.latitude, position.longitude);
    if (nearest == null || !mounted) return;

    if (!_locationDetected && _from == ref.read(bookingDraftProvider).fromCity) {
      setState(() {
        _from = nearest.iata;
        _locationDetected = true;
      });
      ref.read(bookingDraftProvider.notifier).updateSearch(
            fromCity: _from,
            toCity: _to,
            selectedDate: _selectedDate,
            weightKg: _weight,
          );
      _searchTrips();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE, dd MMM yyyy').format(_selectedDate);
    final airportRepo = ref.watch(airportRepositoryProvider);

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: Icon(Icons.help_outline, color: theme.colorScheme.onSurface),
            onPressed: () => Coach.show(
              context,
              force: true,
              storageKey: 'has_seen_book_screen_guide',
              steps: [
                CoachStep(targetKey: _fromKey, title: 'Choose route', body: 'Search and select your origin airport.'),
                CoachStep(targetKey: _toKey, title: 'Pick destination', body: 'Search where the item should go.'),
                CoachStep(targetKey: _dateKey, title: 'Travel date', body: 'Pick when the traveler is flying.'),
                CoachStep(targetKey: _weightKey, title: 'Weight & budget', body: 'Set item weight in kg for matching.'),
                CoachStep(targetKey: _travelerCardKey, title: 'Traveler options', body: 'Tap a traveler to send your request.'),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.share, color: theme.colorScheme.onSurface),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the Date:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateLabel,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Select a date within the next 12 months',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          key: _dateKey,
                          onPressed: _tripsLoading ? null : () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate.isBefore(now)
                                  ? now
                                  : _selectedDate,
                              firstDate: now,
                              lastDate: now.add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedDate = picked;
                              });
                              ref.read(bookingDraftProvider.notifier).updateSearch(
                                    fromCity: _from,
                                    toCity: _to,
                                    selectedDate: _selectedDate,
                                    weightKg: _weight,
                                  );
                              _searchTrips();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(120, 40),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Select date'),
                        ),
                      )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // FROM / TO / WEIGHT SECTION
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'From:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      key: _fromKey,
                      child: AirportSearchField(
                        repository: airportRepo,
                        initialIata: _from,
                        label: 'Origin',
                        enabled: !_tripsLoading,
                        onSelected: (airport) {
                          setState(() => _from = airport.iata);
                          ref.read(bookingDraftProvider.notifier).updateSearch(
                                fromCity: _from,
                                toCity: _to,
                                selectedDate: _selectedDate,
                                weightKg: _weight,
                              );
                          _searchTrips();
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'To:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      key: _toKey,
                      child: AirportSearchField(
                        repository: airportRepo,
                        initialIata: _to,
                        label: 'Destination',
                        enabled: !_tripsLoading,
                        onSelected: (airport) {
                          setState(() => _to = airport.iata);
                          ref.read(bookingDraftProvider.notifier).updateSearch(
                                fromCity: _from,
                                toCity: _to,
                                selectedDate: _selectedDate,
                                weightKg: _weight,
                              );
                          _searchTrips();
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text(
                          'Courier Weight:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.dividerColor,
                            ),
                            color: theme.colorScheme.surface,
                          ),
                          child: Text(
                            '${_weight.toStringAsFixed(1)} KG',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      key: _weightKey,
                      value: _weight,
                      min: 1,
                      max: 30,
                      divisions: 58,
                      label: '${_weight.toStringAsFixed(1)} kg',
                      onChanged: _tripsLoading ? null : (v) {
                        setState(() => _weight = v);
                        ref.read(bookingDraftProvider.notifier).updateSearch(
                              fromCity: _from,
                              toCity: _to,
                              selectedDate: _selectedDate,
                              weightKg: _weight,
                            );
                      },
                      onChangeEnd: (_) => _debouncedSearch(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // TRAVELER CARDS
              if (_tripsLoading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: SkeletonList(items: 3, itemHeight: 80),
                )
              else if (_tripsError != null)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ErrorBanner(_tripsError!),
                )
              else if (_trips.isEmpty)
                EmptyState(
                  icon: Icons.flight_takeoff,
                  title: 'No travelers found',
                  subtitle: 'Try different dates or routes',
                )
              else
                ..._trips.take(5).toList().asMap().entries.map(
                  (entry) {
                    final t = entry.value;
                    final origin = t['origin_airport']?.toString() ?? '';
                    final dest = t['dest_airport']?.toString() ?? '';
                    final capacityKg = t['capacity_kg']?.toString() ?? '';
                    final feePkr = t['fee_pkr']?.toString() ?? '';
                    final airline = t['airline']?.toString() ?? '';
                    final flightNumber = t['flight_number']?.toString() ?? '';
                    return _TravelerCard(
                      key: entry.key == 0 ? _travelerCardKey : null,
                      tripId: t['id'] as int? ?? 0,
                      name: 'Traveler #${t['user_id'] ?? t['id']}',
                      route: '$origin → $dest',
                      rating: '$capacityKg kg',
                      reviews: 'PKR $feePkr/kg',
                      color: AppTheme.primary,
                      airline: airline,
                      flightNumber: flightNumber,
                      onTap: () {
                        ref.read(bookingDraftProvider.notifier).updateSearch(
                              fromCity: _from,
                              toCity: _to,
                              selectedDate: _selectedDate,
                              weightKg: _weight,
                            );
                        context.push('/book/traveler/${t['id']}');
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TravelerCard extends ConsumerStatefulWidget {
  final String name;
  final String route;
  final String rating;
  final String reviews;
  final Color color;
  final String airline;
  final String flightNumber;
  final int tripId;
  final VoidCallback onTap;

  const _TravelerCard({
    super.key,
    required this.name,
    required this.route,
    required this.rating,
    required this.reviews,
    required this.color,
    required this.onTap,
    required this.tripId,
    this.airline = '',
    this.flightNumber = '',
  });

  @override
  ConsumerState<_TravelerCard> createState() => _TravelerCardState();
}

class _TravelerCardState extends ConsumerState<_TravelerCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final savedTrips = ref.read(savedTripsServiceProvider);
    final isSaved = savedTrips.isSaved(widget.tripId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.flight_takeoff, color: widget.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.route,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (widget.flightNumber.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.flight, size: 13, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.airline.isNotEmpty ? '${widget.airline} ' : ''}${widget.flightNumber}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.luggage,
                          size: 14,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.rating,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.reviews,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await savedTrips.toggle(widget.tripId);
                  setState(() {});
                },
                child: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  size: 22,
                  color: isSaved ? AppTheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
