import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import 'booking_draft.dart';

class BookingSuccessScreen extends ConsumerWidget {
  const BookingSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final draft = ref.watch(bookingDraftProvider);
    final bookingId = (extra?['id'] as int?) ?? draft.createdBookingId;
    final route = '${draft.fromCity} -> ${draft.toCity}';
    final traveler = draft.selectedTripIdRaw.isEmpty
        ? 'Selected traveler'
        : 'Trip ${draft.selectedTripIdRaw}';
    final bookingRef = bookingId == null ? '-' : 'BKG-$bookingId';

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
                  color: AppTheme.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 72,
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Booking Created',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Payment deducted and held in escrow',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Escrow info card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            extra?['amount'] != null
                                ? 'PKR ${NumberFormat('#,##0').format(extra!['amount'])} held in escrow'
                                : 'Payment held in escrow',
                            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Released to traveler after delivery confirmation',
                            style: TextStyle(fontSize: 11, color: AppTheme.primary.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: bookingRef));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Booking ID copied!')),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Booking ID',
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(bookingRef, style: theme.textTheme.bodyMedium),
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
                    _Row(label: 'Traveler', value: traveler),
                  ],
                ),
              ),
              if ((draft.pickupOtpDev ?? '').isNotEmpty ||
                  (draft.deliveryOtpDev ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.amber.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.amber.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    'Dev OTPs: pickup ${draft.pickupOtpDev ?? '-'} | delivery ${draft.deliveryOtpDev ?? '-'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
              const SizedBox(height: 24),
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
                      onPressed: () => context.go('/'),
                      child: const Text('Back to Home'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: bookingId == null
                          ? null
                          : () => context.go('/booking/$bookingId/timeline'),
                      child: const Text('View Timeline'),
                    ),
                  ),
                ],
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
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
