import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/kyc_error_handler.dart';
import '../../core/providers.dart';
import '../common/widgets.dart';
import 'trip_draft.dart';

class TripSummaryScreen extends ConsumerStatefulWidget {
  const TripSummaryScreen({super.key});

  @override
  ConsumerState<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends ConsumerState<TripSummaryScreen> {
  bool _submitting = false;

  Future<void> _publishTrip() async {
    final draft = ref.read(tripDraftProvider);
    final capacity = double.tryParse(draft.capacityKg);
    final fee = double.tryParse(draft.feePerKg);
    if (draft.flightDate == null || capacity == null || capacity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flight date and capacity are required.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final tripService = ref.read(tripServiceProvider);
      final created = await tripService.createTrip(
        originAirport: draft.originAirport,
        destinationAirport: draft.destinationAirport,
        flightDate: draft.flightDate!,
        capacityKg: capacity,
        feePkr: fee?.round(),
        flightNumber: draft.flightNumber,
        airline: draft.airline,
      );
      final createdTripId = created['id'] as int?;
      if (createdTripId != null) {
        ref.read(tripDraftProvider.notifier).setCreatedTripId(createdTripId);
      }
      if (!mounted) return;
      context.go('/trip/new/success', extra: created);
    } catch (e) {
      if (!mounted) return;
      if (isKycError(e)) {
        showKycRequiredDialog(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(tripDraftProvider);
    final feeText = draft.feePerKg.isEmpty ? '-' : draft.feePerKg;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: const Text('Review & publish'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Step 3 of 3', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryCard(
              title: 'Route',
              subtitle: '${draft.originAirport} -> ${draft.destinationAirport}',
              trailing: draft.flightDate == null
                  ? null
                  : '${draft.flightDate!.day}/${draft.flightDate!.month}/${draft.flightDate!.year}',
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              title: 'Capacity',
              subtitle: '${draft.capacityKg.isEmpty ? '-' : draft.capacityKg} kg available - Rs. $feeText per kg',
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              title: 'Traveler',
              subtitle: '${draft.travelerName.isEmpty ? 'N/A' : draft.travelerName} - ${draft.travelerPhone.isEmpty ? 'No phone' : draft.travelerPhone}',
            ),
            const Spacer(),
            LoadingButton(
              onPressed: _publishTrip,
              label: 'Publish Trip',
              isLoading: _submitting,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(
      {required this.title, required this.subtitle, this.trailing});
  final String title;
  final String subtitle;
  final String? trailing;

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}

