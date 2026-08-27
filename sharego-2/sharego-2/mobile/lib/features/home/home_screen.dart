import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/widgets.dart';
// ignore: unused_import
import '../notifications/notificatiion_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Map<String, dynamic>? _user;
  double? _walletBalance;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait([
        ref.read(profileServiceProvider).getMe(),
        ref.read(walletServiceProvider).getWallet(limit: 1),
      ]);

      if (mounted) {
        setState(() {
          _user = results[0];
          _walletBalance =
              (results[1]['balance'] as num?)?.toDouble();
          _loading = false;
          _loadError = null;
        });
      }
    } catch (e) {
      if (!mounted) return;

      if (e is DioException &&
          e.response?.statusCode == 401) {
        await ref.read(authStorageProvider).clear();

        if (!mounted) return;

        context.go('/auth/login');
        return;
      }

      setState(() {
        _loading = false;
        _loadError = formatErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final userName =
        _user?['name']?.toString() ??
            _user?['email']?.toString() ??
            'User';

    final city =
        _user?['city']?.toString() ?? '';

    final country =
        _user?['country']?.toString() ?? '';

    final userCity = [
      city,
      country,
    ].where((s) => s.isNotEmpty).join(', ');

    return Scaffold(
      drawer: _HomeDrawer(),

      floatingActionButtonLocation:
          FloatingActionButtonLocation.startFloat,

      floatingActionButton:
          FloatingActionButton.extended(
        heroTag: 'ai-chat-fab',
        onPressed: () => context.push('/ai'),
        icon: const Icon(Icons.chat_bubble),
        label: const Text('AI Chat'),
      ),

      appBar: AppBar(
        elevation: 0,

        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () =>
                Scaffold.of(context).openDrawer(),
          ),
        ),

        actions: [

          // NOTIFICATION ICON ADDED
          IconButton(
            icon: const Icon(
              Icons.notifications_none_rounded,
            ),
            onPressed: () =>
                context.push('/notifications'),
                
          ),

          GestureDetector(
            onTap: () => context.push('/profile'),

            child: Padding(
              padding:
                  const EdgeInsets.only(right: 12.0),

              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primary,

                child: Text(
                  _user != null
                      ? (userName.isNotEmpty
                          ? userName[0]
                              .toUpperCase()
                          : 'U')
                      : 'U',

                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadUser,

          child: SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),

            padding: const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24,
            ),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,

                  children: [

                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [

                        if (userCity.isNotEmpty)
                          Row(
                            children: [

                              const Icon(
                                Icons.location_on,
                                color:
                                    AppTheme.primary,
                                size: 18,
                              ),

                              const SizedBox(
                                  width: 6),

                              Text(
                                userCity,

                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme
                                      .textSecondary,
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 6),

                        Text(
                          'Welcome back',

                          style: theme
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight:
                                    FontWeight.w600,
                              ),
                        ),

                        _loading
                            ? const Padding(
                                padding:
                                    EdgeInsets.only(
                                        top: 4),

                                child: SkeletonBox(
                                  height: 24,
                                  width: 120,
                                ),
                              )
                            : Text(
                                userName,

                                style: theme
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight:
                                          FontWeight
                                              .w800,
                                    ),
                              ),
                      ],
                    ),

                    SizedBox(
                      height: 54,

                      child: Image.asset(
                        'assets/Flyro_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                GestureDetector(
                  onTap: () =>
                      context.push('/wallet'),

                  child: Container(
                    width: double.infinity,

                    padding:
                        const EdgeInsets.all(16),

                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary,
                          AppTheme.primaryDark,
                        ],

                        begin: Alignment.topLeft,
                        end:
                            Alignment.bottomRight,
                      ),

                      borderRadius:
                          BorderRadius.circular(16),

                      boxShadow: [

                        BoxShadow(
                          color: AppTheme.primary
                              .withValues(
                            alpha: 0.25,
                          ),

                          blurRadius: 12,

                          offset:
                              const Offset(0, 4),
                        ),
                      ],
                    ),

                    child: Row(
                      children: [

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,

                            children: [

                              Text(
                                'Wallet Balance',

                                style: theme
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors
                                          .white70,
                                    ),
                              ),

                              const SizedBox(
                                  height: 4),

                              _walletBalance != null
                                  ? Text(
                                      'PKR ${NumberFormat('#,##0', 'en_US').format(_walletBalance)}',

                                      style: theme
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: Colors
                                                .white,

                                            fontWeight:
                                                FontWeight
                                                    .w800,
                                          ),
                                    )
                                  : const SkeletonBox(
                                      height: 28,
                                      width: 120,
                                    ),

                              const SizedBox(
                                  height: 6),

                              Row(
                                children: [

                                  const Icon(
                                    Icons.shield,
                                    color:
                                        Colors.white70,
                                    size: 13,
                                  ),

                                  const SizedBox(
                                      width: 4),

                                  Text(
                                    'Escrow Protected',

                                    style: theme
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors
                                              .white70,

                                          fontWeight:
                                              FontWeight
                                                  .w500,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        const Icon(
                          Icons
                              .account_balance_wallet,
                          color: Colors.white,
                          size: 36,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                if (_loadError != null) ...[
                  ErrorBanner(_loadError!),
                  const SizedBox(height: 10),
                ],

                Text(
                  'Quick actions',

                  style: theme.textTheme.titleMedium
                      ?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 12),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,

                  childAspectRatio: 1.15,

                  physics:
                      const NeverScrollableScrollPhysics(),

                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,

                  children: [

                    _ActionCard(
                      title: 'Send with Traveler',
                      subtitle:
                          'Find a traveler & send your item',

                      icon: Icons.calendar_month,

                      color: AppTheme.primary,

                      onTap: () =>
                          context.push('/book/dates'),
                    ),

                    _ActionCard(
                      title: 'Earn as Traveler',
                      subtitle:
                          'List your trip & share luggage',

                      icon:
                          Icons.flight_takeoff,

                      color: AppTheme.primary
                          .withValues(alpha: 0.7),

                      onTap: () =>
                          context.push('/trip/new/flight'),
                    ),

                    _ActionCard(
                      title: 'Buy & Sell Items',
                      subtitle:
                          'Post items or make offers',

                      icon: Icons
                          .store_mall_directory,

                      color: AppTheme.success,

                      onTap: () =>
                          context.push('/market'),
                    ),

                    _ActionCard(
                      title: 'Report a Problem',
                      subtitle:
                          'Get help or submit issue',

                      icon: Icons
                          .report_gmailerrorred,

                      color: AppTheme.amber,

                      onTap: () =>
                          context.push('/audit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,

      borderRadius:
          BorderRadius.circular(
        AppTheme.borderRadius,
      ),

      child: Container(
        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),

          borderRadius:
              BorderRadius.circular(
            AppTheme.borderRadius,
          ),

          border: Border.all(
            color: color.withValues(
              alpha: 0.4,
            ),
          ),
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            Container(
              padding: const EdgeInsets.all(8),

              decoration: BoxDecoration(
                color: color.withValues(
                  alpha: 0.18,
                ),

                borderRadius:
                    BorderRadius.circular(10),
              ),

              child: Icon(
                icon,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface,
                size: 22,
              ),
            ),

            const Spacer(),

            Text(
              title,

              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
            ),

            const SizedBox(height: 4),

            Text(
              subtitle,

              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,

          children: [

            ListTile(
              leading:
                  const Icon(Icons.person_outline),

              title: const Text('Profile'),

              onTap: () {
                Navigator.pop(context);
                context.push('/profile');
              },
            ),

            ListTile(
              leading: const Icon(
                Icons
                    .account_balance_wallet_outlined,
              ),

              title: const Text('My Wallet'),

              onTap: () {
                Navigator.pop(context);
                context.push('/wallet');
              },
            ),

            ListTile(
              leading: const Icon(
                Icons.book_online_outlined,
              ),

              title:
                  const Text('My Bookings'),

              onTap: () {
                Navigator.pop(context);
                context.push('/bookings');
              },
            ),

            ListTile(
              leading:
                  const Icon(Icons.bookmark_outline),

              title:
                  const Text('Saved Trips'),

              onTap: () {
                Navigator.pop(context);
                context.push('/saved-trips');
              },
            ),

            ListTile(
              leading:
                  const Icon(Icons.chat_bubble),

              title: const Text('AI Chat'),

              onTap: () {
                Navigator.pop(context);
                context.push('/ai');
              },
            ),

            const Divider(),

            ListTile(
              leading:
                  const Icon(Icons.description),

              title: const Text(
                  'Terms & Conditions'),

              onTap: () {
                Navigator.pop(context);

                showDialog(
                  context: context,

                  builder: (_) => AlertDialog(
                    title: const Text(
                        'Terms & Conditions'),

                    content:
                        const SingleChildScrollView(
                      child: Text(
                        'flyro is a peer-to-peer traveler marketplace. '
                        'By using the app you agree to our terms of service. '
                        'All transactions are subject to our escrow policy. '
                        'Users must complete KYC verification before creating bookings or listings. '
                        'flyro is not responsible for items that violate customs regulations.',
                      ),
                    ),

                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context),

                        child:
                            const Text('Close'),
                      )
                    ],
                  ),
                );
              },
            ),

            ListTile(
              leading:
                  const Icon(Icons.privacy_tip),

              title:
                  const Text('Privacy Policy'),

              onTap: () {
                Navigator.pop(context);

                showDialog(
                  context: context,

                  builder: (_) => AlertDialog(
                    title: const Text(
                        'Privacy Policy'),

                    content:
                        const SingleChildScrollView(
                      child: Text(
                        'flyro collects your email, phone, location, and KYC documents '
                        'to provide our services. Your data is stored securely and never '
                        'shared with third parties without consent. You can request data '
                        'deletion by contacting support.',
                      ),
                    ),

                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context),

                        child:
                            const Text('Close'),
                      )
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}