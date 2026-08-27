import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/widgets.dart';

class PickupOtpScreen extends ConsumerStatefulWidget {
  const PickupOtpScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<PickupOtpScreen> createState() => _PickupOtpScreenState();
}

class _PickupOtpScreenState extends ConsumerState<PickupOtpScreen> {
  final _otpController = TextEditingController();
  bool _submitting = false;
  String? _error;
  String? _success;

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      setState(() => _error = 'Enter at least 4 digits');
      return;
    }

    setState(() { _submitting = true; _error = null; });
    try {
      final bookingId = int.parse(widget.id);
      final locService = ref.read(locationServiceProvider);
      final pos = await locService.getCurrentPosition();
      final lat = pos?.latitude ?? 0.0;
      final lng = pos?.longitude ?? 0.0;
      if (pos == null && mounted) {
        setState(() => _error = 'Could not get GPS location. Please enable location services.');
        setState(() => _submitting = false);
        return;
      }
      final service = ref.read(featureAServiceProvider);
      await service.verifyPickup(
        bookingId: bookingId,
        otp: otp,
        gpsLat: lat,
        gpsLng: lng,
        photoPaths: ['pickup_photo.jpg'],
      );
      if (mounted) {
        setState(() { _success = 'Pickup verified successfully!'; _submitting = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _submitting = false; });
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Pickup OTP'), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: AppTheme.primary),
            const SizedBox(height: 12),
            Text('Verify Pickup', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Enter the pickup OTP to confirm handover with the traveler.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_success != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.success),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_success!, style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/booking/${widget.id}/timeline'),
                  child: const Text('Back to Timeline'),
                ),
              ),
            ] else ...[
              TextField(
                controller: _otpController,
                maxLength: 6,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 4, fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  labelText: 'Pickup OTP',
                  hintText: '123456',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  counterText: '',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                ErrorBanner(_error!),
              ],
              const SizedBox(height: 16),
              LoadingButton(
                onPressed: _verify,
                label: 'Verify Pickup',
                isLoading: _submitting,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/booking/${widget.id}/timeline'),
                child: const Text('Back to timeline'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
