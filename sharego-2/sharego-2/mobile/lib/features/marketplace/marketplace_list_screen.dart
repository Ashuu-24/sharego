import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/widgets.dart';
import '../common/coach.dart';

class MarketplaceListScreen extends ConsumerStatefulWidget {
  const MarketplaceListScreen({super.key});

  @override
  ConsumerState<MarketplaceListScreen> createState() => _MarketplaceListScreenState();
}

class _MarketplaceListScreenState extends ConsumerState<MarketplaceListScreen> {
  List<Map<String, dynamic>> _listings = [];
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  double? _userLat;
  double? _userLng;
  bool _nearbyMode = false;
  bool _bannerDismissed = false;
  List<String> _categories = ['All'];

  // My Listings state
  bool _showMine = false;
  List<Map<String, dynamic>> _myListings = [];
  bool _myLoading = false;
  String? _myError;

  final _fabKey = GlobalKey();
  final _filterKey = GlobalKey();
  final _cardKey = GlobalKey();
  final _searchKey = GlobalKey();

  String _extractError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        if (data['error'] is Map<String, dynamic>) {
          final msg = (data['error'] as Map<String, dynamic>)['message']?.toString();
          if (msg != null && msg.isNotEmpty) return msg;
        }
        final detail = data['detail']?.toString();
        if (detail != null && detail.isNotEmpty) return detail;
      } else if (data is String && data.isNotEmpty) {
        return data;
      }
      if (e.response?.statusCode == 403) {
        return 'Access denied for this action.';
      }
      if (e.response?.statusCode == 401) {
        return 'Session expired. Please login again.';
      }
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  @override
  void initState() {
    super.initState();
    _detectLocation();
    _loadListings();
    _loadBannerPref();
    _loadCategories();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Coach.show(
        context,
        storageKey: 'has_seen_market_screen_guide',
        steps: [
          CoachStep(targetKey: _fabKey, title: 'Post listing', body: 'Tap here to add a new listing.'),
          CoachStep(targetKey: _filterKey, title: 'Filter items', body: 'Browse by category.'),
          CoachStep(targetKey: _cardKey, title: 'Open a listing', body: 'View details and send offers.'),
          CoachStep(targetKey: _searchKey, title: 'Search quickly', body: 'Find items by name or location.'),
        ],
      );
    });
  }

  Future<void> _detectLocation() async {
    final locationService = ref.read(locationServiceProvider);
    final position = await locationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _userLat = position.latitude;
        _userLng = position.longitude;
      });
    }
  }

  Future<void> _loadBannerPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _bannerDismissed = prefs.getBool('market_disclaimer_dismissed') ?? false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final service = ref.read(marketplaceServiceProvider);
      final cats = await service.listCategories();
      if (mounted) {
        setState(() => _categories = ['All', ...cats]);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _categories = ['All', 'Electronics', 'Fashion', 'Home', 'Sports', 'Books', 'Other']);
      }
    }
  }

  Future<void> _loadListings() async {
    setState(() { _loading = true; _error = null; });
    try {
      final service = ref.read(marketplaceServiceProvider);
      final result = await service.listListings(
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
        category: _selectedCategory != 'All' ? _selectedCategory : null,
        latitude: _nearbyMode ? _userLat : null,
        longitude: _nearbyMode ? _userLng : null,
        radiusKm: _nearbyMode ? 50 : null,
      );
      if (mounted) setState(() { _listings = result; _loading = false; });
    } catch (e) {
      if (mounted) {
        if (e is DioException && e.response?.statusCode == 401) {
          await ref.read(authStorageProvider).clear();
          if (!mounted) return;
          context.go('/auth/login');
          return;
        }
        setState(() { _error = _extractError(e); _loading = false; });
      }
    }
  }

  Future<void> _loadMyListings() async {
    setState(() { _myLoading = true; _myError = null; });
    try {
      final service = ref.read(marketplaceServiceProvider);
      final result = await service.listMyListings();
      if (mounted) setState(() { _myListings = result; _myLoading = false; });
    } catch (e) {
      if (mounted) {
        if (e is DioException && e.response?.statusCode == 401) {
          await ref.read(authStorageProvider).clear();
          if (!mounted) return;
          context.go('/auth/login');
          return;
        }
        setState(() { _myError = _extractError(e); _myLoading = false; });
      }
    }
  }

  void _onSearch(String value) {
    _searchQuery = value;
    _loadListings();
  }

  void _onCategorySelected(String category) {
    setState(() => _selectedCategory = category);
    _loadListings();
  }

  void _onToggleMode(bool showMine) {
    setState(() => _showMine = showMine);
    if (showMine && _myListings.isEmpty && !_myLoading) {
      _loadMyListings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Marketplace'),
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.onSurfaceVariant),
            onPressed: () => Coach.show(
              context,
              force: true,
              storageKey: 'has_seen_market_screen_guide',
              steps: [
                CoachStep(targetKey: _fabKey, title: 'Post listing', body: 'Tap here to add a new listing.'),
                CoachStep(targetKey: _filterKey, title: 'Filter items', body: 'Browse by category.'),
                CoachStep(targetKey: _cardKey, title: 'Open a listing', body: 'View details and send offers.'),
                CoachStep(targetKey: _searchKey, title: 'Search quickly', body: 'Find items by name or location.'),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await context.push('/market/new');
              _loadListings();
              if (_showMine) _loadMyListings();
            },
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Post listing',
          ),
        ],
      ),
      body: Column(
        children: [
          // Toggle: Browse / My Listings
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Browse')),
                      ButtonSegment(value: true, label: Text('My Listings')),
                    ],
                    selected: {_showMine},
                    onSelectionChanged: (s) => _onToggleMode(s.first),
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                      selectedForegroundColor: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!_showMine) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _SearchBar(key: _searchKey, onSearch: _onSearch),
            ),
            if (!_bannerDismissed)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: DisclaimerBanner(
                  onDismiss: () async {
                    setState(() => _bannerDismissed = true);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('market_disclaimer_dismissed', true);
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_userLat != null && _userLng != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: Icon(Icons.near_me, size: 16, color: _nearbyMode ? AppTheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
                          label: const Text('Nearby'),
                          selected: _nearbyMode,
                          onSelected: (v) {
                            setState(() => _nearbyMode = v);
                            _loadListings();
                          },
                          selectedColor: AppTheme.primary.withValues(alpha: 0.12),
                          checkmarkColor: AppTheme.primary,
                          shape: StadiumBorder(side: BorderSide(color: Theme.of(context).dividerColor)),
                        ),
                      ),
                    ..._categories.map((cat) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          key: cat == 'All' ? _filterKey : null,
                          label: Text(cat),
                          selected: _selectedCategory == cat,
                          onSelected: (_) => _onCategorySelected(cat),
                          selectedColor: AppTheme.primary.withValues(alpha: 0.12),
                          checkmarkColor: AppTheme.primary,
                          shape: StadiumBorder(side: BorderSide(color: Theme.of(context).dividerColor)),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
          Expanded(
            child: _showMine ? _buildMyListings() : _buildBrowseListings(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        key: _fabKey,
        onPressed: () async {
          await context.push('/market/new');
          _loadListings();
          if (_showMine) _loadMyListings();
        },
        icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
        label: const Text('Create listing' ,style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildBrowseListings() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: SkeletonList(items: 3, itemHeight: 120),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load listings', style: TextStyle(color: Colors.red.shade700)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _loadListings, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_listings.isEmpty) {
      return const EmptyState(
        icon: Icons.store_mall_directory,
        title: 'No listings found',
        subtitle: 'Try a different search or category',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadListings,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        itemCount: _listings.length,
        itemBuilder: (context, i) => _buildListingCard(_listings[i], i == 0 ? _cardKey : null),
      ),
    );
  }

  Widget _buildMyListings() {
    if (_myLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: SkeletonList(items: 3, itemHeight: 120),
      );
    }
    if (_myError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load your listings', style: TextStyle(color: Colors.red.shade700)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _loadMyListings, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_myListings.isEmpty) {
      return const EmptyState(
        icon: Icons.storefront,
        title: 'No listings yet',
        subtitle: 'Tap "Create listing" to post your first item',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadMyListings,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        itemCount: _myListings.length,
        itemBuilder: (context, i) => _buildListingCard(_myListings[i], null),
      ),
    );
  }

  Widget _buildListingCard(Map<String, dynamic> l, Key? key) {
    final photos = l['photos_paths'];
    String? thumbUrl;
    if (photos is List && photos.isNotEmpty) {
      final p = photos[0].toString();
      final baseUrl = ref.read(envConfigProvider).apiBaseUrl;
      thumbUrl = p.startsWith('http') ? p : '$baseUrl/media/$p';
    }
    return _ListingCard(
      key: key,
      title: l['title']?.toString() ?? '',
      price: 'PKR ${(l['ask_price'] ?? 0).toStringAsFixed(0)}',
      location: l['location_text']?.toString() ?? '',
      status: l['status']?.toString().toUpperCase() ?? 'ACTIVE',
      category: l['category']?.toString() ?? '',
      imageUrl: thumbUrl,
      onTap: () async {
        await context.push('/market/${l['id']}');
        _loadListings();
        if (_showMine) _loadMyListings();
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({super.key, required this.onSearch});
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onSubmitted: onSearch,
      decoration: InputDecoration(
        hintText: 'Search items, categories, locations',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary)),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    super.key,
    required this.title,
    required this.price,
    required this.location,
    required this.status,
    required this.category,
    required this.onTap,
    this.imageUrl,
  });

  final String title;
  final String price;
  final String location;
  final String status;
  final String category;
  final VoidCallback onTap;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusTone = switch (status) {
      'SOLD' => StatusTone.success,
      'REMOVED' => StatusTone.danger,
      'PAUSED' => StatusTone.warning,
      _ => StatusTone.info,
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 86,
              height: 86,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surfaceContainerLow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        width: 86,
                        height: 86,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.image_outlined, size: 36, color: theme.colorScheme.onSurfaceVariant),
                      )
                    : Icon(Icons.image_outlined, size: 36, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(price, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                    const SizedBox(height: 4),
                    Text(location, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        StatusPill(status, tone: statusTone),
                        if (category.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(category, style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
