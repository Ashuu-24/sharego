import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';

class BookingUnderReviewScreen extends StatefulWidget {
  const BookingUnderReviewScreen({super.key});

  @override
  State<BookingUnderReviewScreen> createState() =>
      _BookingUnderReviewScreenState();
}

class _BookingUnderReviewScreenState extends State<BookingUnderReviewScreen> {
  String status = 'Your booking request is under review.';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        status = 'Approved';
      });
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          context.go('/book/success');
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.verified, size: 48, color: AppTheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                status,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'We are validating the request details. You will be redirected once approved.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              LinearProgressIndicator(
                minHeight: 4,
                color: AppTheme.primary,
                backgroundColor: theme.dividerColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
