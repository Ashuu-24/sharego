import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/widgets.dart';

class FlightTrackingCard extends ConsumerStatefulWidget {
  const FlightTrackingCard({super.key, required this.tripId});
  final int tripId;

  @override
  ConsumerState<FlightTrackingCard> createState() => _FlightTrackingCardState();
}

class _FlightTrackingCardState extends ConsumerState<FlightTrackingCard> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFlightStatus();
  }

  Future<void> _loadFlightStatus() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ref.read(tripServiceProvider).getFlightStatus(widget.tripId);
      if (mounted) setState(() { _data = result; _loading = false; });
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        setState(() { _error = msg; _loading = false; });
      }
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'landed':
        return AppTheme.success;
      case 'scheduled':
        return AppTheme.amber;
      case 'cancelled':
      case 'diverted':
        return AppTheme.danger;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SkeletonBox(width: double.infinity, height: 100),
      );
    }

    if (_error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Flight status unavailable',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _loadFlightStatus,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }

    final flightStatus = _data?['flight_status']?.toString() ?? 'unknown';
    final departure = _data?['departure'] as Map<String, dynamic>?;
    final arrival = _data?['arrival'] as Map<String, dynamic>?;
    final statusColor = _statusColor(flightStatus);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.symmetric(vertical: 8),
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
              Icon(Icons.flight, size: 18, color: statusColor),
              const SizedBox(width: 6),
              const Text(
                'Flight Tracking',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  flightStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _loadFlightStatus,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (flightStatus != 'not_found') ...[
            const SizedBox(height: 10),
            if (departure != null)
              _TimeRow(
                label: 'Departure',
                airport: departure['iata']?.toString() ?? '',
                scheduled: departure['scheduled']?.toString(),
                actual: departure['actual']?.toString(),
                delay: departure['delay'],
              ),
            if (arrival != null)
              _TimeRow(
                label: 'Arrival',
                airport: arrival['iata']?.toString() ?? '',
                scheduled: arrival['scheduled']?.toString(),
                actual: arrival['actual']?.toString(),
                delay: arrival['delay'],
              ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Flight not found in tracking system.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.airport,
    this.scheduled,
    this.actual,
    this.delay,
  });

  final String label;
  final String airport;
  final String? scheduled;
  final String? actual;
  final dynamic delay;

  String _formatTime(String? ts) {
    if (ts == null) return '--';
    // AviationStack returns ISO timestamps; show time portion.
    final dt = DateTime.tryParse(ts);
    if (dt == null) return ts;
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final delayMin = delay is int ? delay as int : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 75,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            airport,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTime(scheduled),
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          if (actual != null) ...[
            const Text(' → ', style: TextStyle(fontSize: 12)),
            Text(
              _formatTime(actual),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          if (delayMin != null && delayMin > 0) ...[
            const SizedBox(width: 6),
            Text(
              '+${delayMin}m',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
