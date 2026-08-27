import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_theme.dart';

/// Returns true if [error] is a 403 KYC enforcement response.
bool isKycError(Object error) {
  if (error is DioException && error.response?.statusCode == 403) {
    final data = error.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString().toLowerCase().contains('kyc');
    }
    if (data is Map && data['error'] is Map) {
      final message = (data['error'] as Map)['message']?.toString() ?? '';
      return message.toLowerCase().contains('kyc');
    }
    if (data is String) {
      return data.toLowerCase().contains('kyc');
    }
  }
  return false;
}

/// Shows a styled bottom sheet explaining KYC is required, with a
/// "Go to KYC" action button that navigates to the KYC screen.
void showKycRequiredDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.verified_user_outlined,
                    color: AppTheme.amber, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'KYC Verification Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please submit and get your KYC approved before proceeding.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/profile/kyc');
                  },
                  child: const Text('Go to KYC'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
