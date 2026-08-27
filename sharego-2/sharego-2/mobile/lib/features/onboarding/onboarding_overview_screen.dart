import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

class OnboardingOverviewScreen extends ConsumerWidget {
  const OnboardingOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            /// Soft Background Glow
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                height: 180,
                width: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.08),
                ),
              ),
            ),

            Positioned(
              bottom: -80,
              left: -50,
              child: Container(
                height: 220,
                width: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.05),
                ),
              ),
            ),

            ListView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
              children: [
                const SizedBox(height: 28),

                /// Logo
                Center(
                  child: Container(
                    height: 115,
                    width: 115,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      border: Border.all(
                        color:
                            theme.colorScheme.primary.withOpacity(0.12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/Flyro_Logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                /// Heading
                Center(
                  child: Text(
                    'Welcome to Flyro',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      height: 1.1,
                      color: theme.colorScheme.onBackground,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                /// Brief Description
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Travel smarter, connect globally,\nand earn through extra luggage space.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14.5,
                        height: 1.8,
                        color: theme.colorScheme.onBackground
                            .withOpacity(0.68),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 42),

                /// Cards
                _GlassCard(
                  icon: Icons.flight_takeoff_rounded,
                  title: 'Travel & Earn',
                  subtitle:
                      'Post trips and earn using unused luggage space.',
                ),

                const SizedBox(height: 18),

                _GlassCard(
                  icon: Icons.shopping_bag_rounded,
                  title: 'Global Shopping',
                  subtitle:
                      'Send requests through trusted travelers worldwide.',
                ),

                const SizedBox(height: 18),

                _GlassCard(
                  icon: Icons.storefront_rounded,
                  title: 'Marketplace',
                  subtitle:
                      'Buy and sell products internationally with ease.',
                ),

                const SizedBox(height: 40),

                /// Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      await ref
                          .read(authStorageProvider)
                          .markOnboardingCompleted();

                      if (context.mounted) {
                        context.go('/auth/login');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      'Get Started',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(0.01)
        ..rotateY(-0.01),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 12,
            sigmaY: 12,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor.withOpacity(0.82),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: theme.dividerColor.withOpacity(0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                /// Icon Box
                Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color:
                        theme.colorScheme.primary.withOpacity(0.12),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary
                            .withOpacity(0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 18),

                /// Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color:
                              theme.colorScheme.onBackground,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13.5,
                          height: 1.6,
                          color: theme.colorScheme.onBackground
                              .withOpacity(0.65),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}