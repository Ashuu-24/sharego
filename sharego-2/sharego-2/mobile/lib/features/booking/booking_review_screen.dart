import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/widgets.dart';
import 'booking_draft.dart';

class BookingReviewScreen extends ConsumerStatefulWidget {
  const BookingReviewScreen({super.key});

  @override
  ConsumerState<BookingReviewScreen> createState() => _BookingReviewScreenState();
}

class _BookingReviewScreenState extends ConsumerState<BookingReviewScreen> {
  bool _submitting = false;
  double? _walletBalance;
  bool _loadingBalance = true;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final wallet = await ref.read(walletServiceProvider).getWallet(limit: 1);
      if (mounted) {
        setState(() {
          _walletBalance = (wallet['balance'] as num?)?.toDouble() ?? 0;
          _loadingBalance = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _confirm() async {
    final draft = ref.read(bookingDraftProvider);
    final tripId = draft.selectedTripId;
    final weight = double.tryParse(draft.itemWeight);
    final price = double.tryParse(draft.itemPrice);
    if (tripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a traveler before confirming.')),
      );
      return;
    }
    if (weight == null || weight <= 0 || price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid weight or price in booking details.')),
      );
      return;
    }

    // Show processing dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing payment...', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );

    setState(() => _submitting = true);
    try {
      final service = ref.read(featureAServiceProvider);
      final start = DateTime(
        draft.selectedDate.year,
        draft.selectedDate.month,
        draft.selectedDate.day,
      );
      final end = start.add(const Duration(days: 3));
      final request = await service.createRequest(
        productName: draft.itemName,
        specsJson: jsonEncode({
          'description': draft.itemDescription,
          'sender_name': draft.senderName,
          'sender_email': draft.senderEmail,
          'sender_phone': draft.senderPhone,
          'from_city': draft.fromCity,
        }),
        targetPrice: price,
        destCity: draft.toCity,
        weightKg: weight,
        windowStart: start,
        windowEnd: end,
      );
      final requestId = _asInt(request['id']);
      if (requestId == null) {
        throw Exception('Request creation succeeded without a valid request ID.');
      }
      final booking = await service.createBooking(
        tripId: tripId,
        requestId: requestId,
        amount: price,
        currency: 'PKR',
      );
      final bookingId = _asInt(booking['id']);
      if (bookingId == null) {
        throw Exception('Booking creation succeeded without a valid booking ID.');
      }
      ref.read(bookingDraftProvider.notifier).setCreatedData(
            requestId: requestId,
            bookingId: bookingId,
            pickupOtpDev: booking['pickup_otp_dev']?.toString(),
            deliveryOtpDev: booking['delivery_otp_dev']?.toString(),
          );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss processing dialog
      context.go('/book/success', extra: booking);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss processing dialog
      String errorMsg = e.toString().replaceFirst('Exception: ', '');
      if (e is DioException && e.response != null) {
        final data = e.response?.data;
        if (data is Map && data['detail'] is Map && data['detail']['message'] == 'Insufficient wallet balance') {
          final balance = data['detail']['balance'];
          final required_ = data['detail']['required'];
          errorMsg = 'Insufficient balance. You have PKR ${NumberFormat('#,##0').format(balance)} but need PKR ${NumberFormat('#,##0').format(required_)}.';
        } else {
          errorMsg = 'Status ${e.response?.statusCode}: ${e.response?.data}';
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), duration: const Duration(seconds: 6)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);
    final price = double.tryParse(draft.itemPrice) ?? 0;
    final formatter = NumberFormat('#,##0', 'en_US');
    final hasEnough = _walletBalance != null && _walletBalance! >= price;
    final balanceAfter = (_walletBalance ?? 0) - price;

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Review & Confirm',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SummaryRow(label: 'Item', value: draft.itemName),
                            const Divider(height: 1),
                            _SummaryRow(label: 'Weight', value: '${draft.itemWeight} kg'),
                            const Divider(height: 1),
                            _SummaryRow(label: 'Price', value: 'PKR ${draft.itemPrice}'),
                            const Divider(height: 1),
                            _SummaryRow(label: 'To', value: draft.toCity),
                            const Divider(height: 1),
                            _SummaryRow(label: 'Trip', value: draft.selectedTripIdRaw),
                            const Divider(height: 1),
                            _SummaryRow(label: 'Sender', value: draft.senderName),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Payment Summary
                      Text(
                        'Payment Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: _loadingBalance
                            ? const Center(child: Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ))
                            : Column(
                                children: [
                                  _SummaryRow(
                                    label: 'Item Price',
                                    value: 'PKR ${formatter.format(price)}',
                                  ),
                                  const Divider(height: 1),
                                  _SummaryRow(
                                    label: 'Wallet Balance',
                                    value: 'PKR ${formatter.format(_walletBalance ?? 0)}',
                                  ),
                                  const Divider(height: 1),
                                  _SummaryRow(
                                    label: 'Balance After',
                                    value: 'PKR ${formatter.format(balanceAfter)}',
                                    valueColor: balanceAfter >= 0 ? AppTheme.success : AppTheme.danger,
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 12),

                      // Escrow badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shield, color: AppTheme.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Funds held in escrow until delivery is confirmed',
                                style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Insufficient balance warning
                      if (!_loadingBalance && !hasEnough) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber, color: AppTheme.danger, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Insufficient wallet balance. You need PKR ${formatter.format(price - (_walletBalance ?? 0))} more.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.danger, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              LoadingButton(
                onPressed: (!_loadingBalance && hasEnough) ? _confirm : null,
                label: price > 0 ? 'Pay PKR ${formatter.format(price)} & Confirm' : 'Confirm',
                isLoading: _submitting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: valueColor != null ? TextStyle(color: valueColor, fontWeight: FontWeight.w600) : null,
            ),
          ),
        ],
      ),
    );
  }
}
