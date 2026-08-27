import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import 'trip_draft.dart';

class TripSuccessScreen extends ConsumerWidget {
  const TripSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final draft = ref.watch(tripDraftProvider);
    final tripId = extra?['id']?.toString() ?? draft.createdTripId?.toString() ?? 'N/A';
    final route = '${draft.originAirport} -> ${draft.destinationAirport}';
    final capacity = '${draft.capacityKg.isEmpty ? '-' : draft.capacityKg} kg - Rs. ${draft.feePerKg.isEmpty ? '-' : draft.feePerKg}/kg';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppTheme.amber.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.hourglass_top_rounded, size: 72, color: AppTheme.amber),
              ),
              const SizedBox(height: 16),
              Text(
                'Trip Submitted',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Your trip is under review. You\'ll be notified once an admin approves it.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: tripId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Trip ID copied!')),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Trip ID',
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(tripId, style: theme.textTheme.bodyMedium),
                              const SizedBox(width: 4),
                              Icon(Icons.copy, size: 14, color: theme.colorScheme.onSurfaceVariant),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Row(label: 'Route', value: route),
                    const SizedBox(height: 8),
                    _Row(label: 'Capacity', value: capacity),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Back to Home'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: tripId == 'N/A'
                          ? null
                          : () => context.go('/trip/$tripId'),
                      child: const Text('View Trip'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.go('/trip/manage'),
                child: const Text('Manage my trips'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

