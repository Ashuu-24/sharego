import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/kyc_error_handler.dart';
import '../../core/providers.dart';
import '../common/airline_search_field.dart';
import '../common/airport_search_field.dart';
import '../common/coach.dart';
import '../common/widgets.dart';
import 'trip_draft.dart';

class TripFlightScreen extends ConsumerStatefulWidget {
  const TripFlightScreen({super.key});

  @override
  ConsumerState<TripFlightScreen> createState() => _TripFlightScreenState();
}

class _TripFlightScreenState extends ConsumerState<TripFlightScreen> {
  String _country = 'Pakistan';
  String _fromCode = 'LHE';
  String _toCode = 'RUH';
  String _airlineName = '';
  String _airlineIata = '';
  DateTime _flightDate = DateTime.now();
  bool _locationDetected = false;

  String? _formError;
  final _ticketCtrl = TextEditingController();
  final _flightNumberCtrl = TextEditingController();
  final _routeKey = GlobalKey();
  final _fromKey = GlobalKey();
  final _toKey = GlobalKey();
  final _dateKey = GlobalKey();
  final _continueKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final draft = ref.read(tripDraftProvider);
    _country = draft.country;
    _fromCode = draft.originAirport;
    _toCode = draft.destinationAirport;
    _flightDate = draft.flightDate ?? DateTime.now();
    _ticketCtrl.text = draft.eticketUrl;
    _airlineName = draft.airline;
    _flightNumberCtrl.text = draft.flightNumber;
    // Try to resolve airline IATA from name for initial selection.
    final airlineRepo = ref.read(airlineRepositoryProvider);
    final results = airlineRepo.search(draft.airline, limit: 1);
    if (results.isNotEmpty && results.first.name == draft.airline) {
      _airlineIata = results.first.iata;
    }
    _detectLocation();
    _checkKycStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Coach.show(
        context,
        storageKey: 'has_seen_trip_flight_guide',
        steps: [
          CoachStep(
            targetKey: _routeKey,
            title: 'Route & airline',
            body: 'Pick your airline and country.',
          ),
          CoachStep(
            targetKey: _fromKey,
            title: 'From airport',
            body: 'Search and choose your origin airport.',
          ),
          CoachStep(
            targetKey: _toKey,
            title: 'To airport',
            body: 'Search and choose your destination airport.',
          ),
          CoachStep(
            targetKey: _dateKey,
            title: 'Flight date',
            body: 'Set when you fly.',
          ),
          CoachStep(
            targetKey: _continueKey,
            title: 'Continue',
            body: 'Go next to add capacity & publish.',
          ),
        ],
      );
    });
  }

  @override
  void dispose() {
    _ticketCtrl.dispose();
    _flightNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkKycStatus() async {
    try {
      final profile = await ref.read(profileServiceProvider).getMe();
      if (!mounted) return;
      final kycStatus = profile['kyc_status']?.toString() ?? 'pending';
      if (kycStatus != 'approved') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showKycRequiredDialog(context);
        });
      }
    } catch (_) {
      // Don't block on failure — the server will enforce anyway
    }
  }

  Future<void> _detectLocation() async {
    final locationService = ref.read(locationServiceProvider);
    final position = await locationService.getCurrentPosition();
    if (position == null || !mounted) return;

    final airportRepo = ref.read(airportRepositoryProvider);
    final nearest = airportRepo.nearestTo(position.latitude, position.longitude);
    if (nearest == null || !mounted) return;

    if (!_locationDetected && _fromCode == ref.read(tripDraftProvider).originAirport) {
      setState(() {
        _fromCode = nearest.iata;
        _locationDetected = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = DateFormat('EEE, dd MMM yyyy').format(_flightDate);
    final airportRepo = ref.watch(airportRepositoryProvider);
    final airlineRepo = ref.watch(airlineRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: const Text('Trip setup'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Step 1 of 3', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: Icon(Icons.help_outline, color: theme.colorScheme.onSurface),
            onPressed: () => Coach.show(
              context,
              force: true,
              storageKey: 'has_seen_trip_flight_guide',
              steps: [
                CoachStep(
                  targetKey: _routeKey,
                  title: 'Route & airline',
                  body: 'Pick your airline and country.',
                ),
                CoachStep(
                  targetKey: _fromKey,
                  title: 'From airport',
                  body: 'Search and choose your origin airport.',
                ),
                CoachStep(
                  targetKey: _toKey,
                  title: 'To airport',
                  body: 'Search and choose your destination airport.',
                ),
                CoachStep(
                  targetKey: _dateKey,
                  title: 'Flight date',
                  body: 'Set when you fly.',
                ),
                CoachStep(
                  targetKey: _continueKey,
                  title: 'Continue',
                  body: 'Go next to add capacity & publish.',
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionCard(
              key: _routeKey,
              title: 'Route & airline',
              children: [
                _FieldLabel('From airport'),
                SizedBox(
                  key: _fromKey,
                  child: AirportSearchField(
                    repository: airportRepo,
                    initialIata: _fromCode,
                    label: 'Origin',
                    onSelected: (airport) {
                      setState(() {
                        _fromCode = airport.iata;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _FieldLabel('To airport'),
                SizedBox(
                  key: _toKey,
                  child: AirportSearchField(
                    repository: airportRepo,
                    initialIata: _toCode,
                    label: 'Destination',
                    onSelected: (airport) {
                      setState(() {
                        _toCode = airport.iata;
                        _country = airport.country;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _FieldLabel('Airline'),
                AirlineSearchField(
                  repository: airlineRepo,
                  initialIata: _airlineIata.isNotEmpty ? _airlineIata : null,
                  label: 'Airline',
                  onSelected: (airline) {
                    setState(() {
                      _airlineName = airline.name;
                      _airlineIata = airline.iata;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Flight information',
              children: [
                _FieldLabel('Flight number'),
                TextField(
                  controller: _flightNumberCtrl,
                  decoration: _input('e.g. SV735'),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 14),
                _FieldLabel('E-ticket URL'),
                TextField(
                  controller: _ticketCtrl,
                  decoration: _input('https://airline.com/ticket'),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 14),
                _FieldLabel('Date of flight'),
                Card(
                  key: _dateKey,
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: theme.dividerColor),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    title: Text(
                      dateLabel,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Select a date within next 12 months'),
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(120, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                _flightDate.isBefore(now) ? now : _flightDate,
                            firstDate: now,
                            lastDate: now.add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => _flightDate = picked);
                          }
                        },
                        child: const Text('Select'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_formError != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(_formError!),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                key: _continueKey,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (_fromCode == _toCode) {
                    setState(() => _formError = 'Origin and destination cannot be the same.');
                    return;
                  }
                  if (_airlineName.isEmpty) {
                    setState(() => _formError = 'Please select an airline.');
                    return;
                  }
                  if (_flightNumberCtrl.text.trim().isEmpty) {
                    setState(() => _formError = 'Flight number is required.');
                    return;
                  }
                  if (_ticketCtrl.text.trim().isEmpty) {
                    setState(() => _formError = 'E-ticket URL is required.');
                    return;
                  }
                  setState(() => _formError = null);
                  ref.read(tripDraftProvider.notifier).updateFlight(
                        country: _country,
                        airline: _airlineName,
                        originAirport: _fromCode,
                        destinationAirport: _toCode,
                        flightDate: _flightDate,
                        eticketUrl: _ticketCtrl.text,
                        flightNumber: _flightNumberCtrl.text.trim(),
                      );
                  context.push('/trip/new/capacity');
                },
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.4),
        ),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}
