import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/widgets.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController(text: '+92');
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _useOtp = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    emailCtrl.dispose();
    phoneCtrl.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw Exception('Failed to get Google ID token');
      }
      final token = await ref.read(authServiceProvider).signInWithGoogle(idToken);
      await ref.read(authStorageProvider).saveToken(token);
      if (!mounted) return;
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
        if (mounted) context.go('/auth/profile-setup');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerWithPassword() async {
    final email = emailCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final password = passwordCtrl.text;
    final confirm = confirmPasswordCtrl.text;
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final token = await ref.read(authServiceProvider).registerWithPassword(
        email, password, phone: phone.isEmpty ? null : phone,
      );
      await ref.read(authStorageProvider).saveToken(token);
      if (!mounted) return;
      context.go('/auth/profile-setup');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestOtp() async {
    final email = emailCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final otpDev = await ref.read(authServiceProvider).requestOtp(
            email,
            phone: phone.isEmpty ? null : phone,
          );
      if (!mounted) return;
      context.go('/auth/otp', extra: {'email': email, 'phone': phone, 'otp_dev': otpDev});
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
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.3),
                      Colors.white,
                    ],
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // LOGO
                    SizedBox(
                      width: 180,
                      child: Image.asset(
                        'assets/Flyro_logo2.png',
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 22),

                    // WHITE CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Sign Up",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // SOCIAL SIGNUP
                          Row(
                            children: [
                              const Text("Sign Up with:   "),
                              GestureDetector(
                                onTap: _loading ? null : _signInWithGoogle,
                                child: const Image(
                                    image: AssetImage("assets/google.png"),
                                    width: 22),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // EMAIL
                          TextField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: "Email:",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // PHONE
                          TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: "Phone:",
                              border: OutlineInputBorder(),
                            ),
                          ),

                          if (!_useOtp) ...[
                            const SizedBox(height: 14),

                            // PASSWORD
                            TextField(
                              controller: passwordCtrl,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: "Password:",
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // CONFIRM PASSWORD
                            TextField(
                              controller: confirmPasswordCtrl,
                              obscureText: _obscurePassword,
                              decoration: const InputDecoration(
                                labelText: "Confirm Password:",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // ERROR BANNER
                          if (_error != null) ...[
                            ErrorBanner(_error!),
                            const SizedBox(height: 12),
                          ],

                          // SIGNUP BUTTON
                          LoadingButton(
                            onPressed: _useOtp ? _requestOtp : _registerWithPassword,
                            label: _useOtp ? 'Sign Up with OTP' : 'Sign Up',
                            isLoading: _loading,
                          ),

                          const SizedBox(height: 12),

                          // TOGGLE OTP / PASSWORD
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => context.pop(),
                                child: Text(
                                  "Back to Login",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() {
                                  _useOtp = !_useOtp;
                                  _error = null;
                                }),
                                child: Text(
                                  _useOtp ? "Use Password" : "Use OTP Instead",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // FOOTER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary,
                  AppTheme.primary.withValues(alpha: 0.8),
                  AppTheme.primary.withValues(alpha: 0.6),
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {},
                  child: const Text("Terms & Condition",
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                ),
                GestureDetector(
                  onTap: () {},
                  child: const Text("Privacy Policy",
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
