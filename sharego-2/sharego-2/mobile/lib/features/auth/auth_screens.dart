import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/widgets.dart';

export 'login_screen.dart';
export 'signup_screen.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final otpCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  // Resend cooldown
  int _resendCooldown = 0;
  Timer? _resendTimer;

  // OTP expiry countdown (5 minutes)
  int _expirySeconds = 300;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _startExpiryTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
      final otpDev = extra?['otp_dev']?.toString() ?? '';
      if (otpDev.isNotEmpty) {
        otpCtrl.text = otpDev;
      }
    });
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    _expirySeconds = 300;
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _expirySeconds--;
        if (_expirySeconds <= 0) timer.cancel();
      });
    });
  }

  void _startResendCooldown() {
    _resendCooldown = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) timer.cancel();
      });
    });
  }

  @override
  void dispose() {
    otpCtrl.dispose();
    _resendTimer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    final email = (GoRouterState.of(context).extra as Map<String, dynamic>?)?['email']?.toString() ?? '';
    final otp = otpCtrl.text.trim();
    if (email.isEmpty || otp.length < 4) {
      setState(() => _error = 'Enter a valid OTP.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final auth = ref.read(authServiceProvider);
      final token = await auth.verifyOtp(email, otp);
      await ref.read(authStorageProvider).saveToken(token);
      if (!mounted) return;

      // Check if user has set their display name yet.
      try {
        final profile = await ref.read(profileServiceProvider).getMe();
        final name = profile['name']?.toString() ?? '';
        if (!mounted) return;
        if (name.isEmpty) {
          context.go('/auth/profile-setup');
        } else {
          context.go('/');
        }
      } catch (_) {
        // If profile fetch fails, send to setup to be safe.
        if (mounted) context.go('/auth/profile-setup');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0) return;
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final email = extra?['email']?.toString() ?? '';
    final phone = extra?['phone']?.toString();
    if (email.isEmpty) return;
    try {
      final auth = ref.read(authServiceProvider);
      final otpDev = await auth.requestOtp(email, phone: phone);
      if (!mounted) return;
      if (otpDev.isNotEmpty) {
        otpCtrl.text = otpDev;
      }
      _startResendCooldown();
      _startExpiryTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP resent')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _formatExpiry() {
    if (_expirySeconds <= 0) return 'Expired';
    final m = _expirySeconds ~/ 60;
    final s = _expirySeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final email = (GoRouterState.of(context).extra as Map<String, dynamic>?)?['email']?.toString() ?? 'your email';
    return Scaffold(
      appBar: AppBar(title: const Text('Enter OTP')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('We sent a 6-digit code to $email.'),
            if ((GoRouterState.of(context).extra as Map<String, dynamic>?)?['otp_dev'] != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Text(
                  'Dev mode: OTP auto-filled',
                  style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Expires in ${_formatExpiry()}',
              style: TextStyle(
                color: _expirySeconds <= 60 ? AppTheme.danger : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpCtrl,
              maxLength: 6,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
              ),
              decoration: const InputDecoration(
                labelText: 'OTP',
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
              label: 'Verify & Continue',
              isLoading: _submitting,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _resendCooldown > 0 || _submitting ? null : _resend,
              child: Text(
                _resendCooldown > 0 ? 'Resend OTP (${_resendCooldown}s)' : 'Resend OTP',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final emailCtrl = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = emailCtrl.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final otpDev = await ref.read(authServiceProvider).forgotPassword(email);
      if (!mounted) return;
      context.go('/auth/otp', extra: {'email': email, 'otp_dev': otpDev});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your email to receive a one-time code',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 16),
            LoadingButton(
              onPressed: _submit,
              label: 'Send reset / OTP',
              isLoading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}
