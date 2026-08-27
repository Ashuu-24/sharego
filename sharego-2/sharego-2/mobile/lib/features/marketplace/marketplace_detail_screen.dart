import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/widgets.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  Map<String, dynamic>? _listing;
  bool _loading = true;
  String? _error;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _fetchListing();
  }

  Future<void> _fetchListing() async {
    try {
      final service = ref.read(marketplaceServiceProvider);
      final results = await Future.wait([
        service.getListing(int.parse(widget.id)),
        ref.read(profileServiceProvider).getMe(),
      ]);
      if (mounted) {
        setState(() {
          _listing = results[0];
          _currentUserId = results[1]['id'] as int?;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = formatErrorMessage(e); _loading = false; });
    }
  }

  Future<void> _confirmRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove listing?'),
        content: const Text('This listing will be marked as removed and hidden from buyers.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final service = ref.read(marketplaceServiceProvider);
      await service.removeListing(int.parse(widget.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing removed')),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${formatErrorMessage(e)}')),
        );
      }
    }
  }

  bool get _isOwner =>
      _currentUserId != null &&
      _listing != null &&
      _listing!['seller_id'] == _currentUserId;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(elevation: 0, title: const Text('Listing')),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: SkeletonList(items: 4, itemHeight: 80),
        ),
      );
    }

    if (_error != null || _listing == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(elevation: 0, title: const Text('Listing')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? 'Listing not found', style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 12),
              TextButton(onPressed: () { setState(() { _loading = true; _error = null; }); _fetchListing(); }, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final listing = _listing!;
    final config = ref.watch(envConfigProvider);
    final images = _extractImages(listing, config.apiBaseUrl);
    final title = listing['title']?.toString() ?? '';
    final desc = listing['description']?.toString() ?? '';
    final price = listing['ask_price'] ?? listing['price'];
    final priceStr = price != null ? 'PKR ${price.toString()}' : '';
    final statusStr = listing['status']?.toString() ?? 'ACTIVE';
    final location = listing['location_text']?.toString() ?? '';
    final category = listing['category']?.toString() ?? 'General';
    final condition = listing['condition']?.toString() ?? 'Used';
    final sellerName = listing['seller_name']?.toString() ?? 'Seller';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        title: Text(title),
        actions: [
          IconButton(
            onPressed: () => context.push('/audit/report/new'),
            icon: const Icon(Icons.report_problem_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: [
          if (images.isNotEmpty) _ImageGrid(images: images),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(desc.isNotEmpty ? desc : 'No description', style: const TextStyle(fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(priceStr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary)),
              StatusPill(statusStr, tone: StatusTone.info),
            ],
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.place_outlined, size: 18, color: Colors.black54),
              const SizedBox(width: 4),
              Text(location, style: const TextStyle(fontSize: 13, color: Colors.black54)),
            ]),
          ],
          const SizedBox(height: 16),
          const DisclaimerBanner(),
          const SizedBox(height: 16),
          _SellerCard(name: sellerName),
          const SizedBox(height: 16),
          _InfoRow(label: 'Category', value: category),
          _InfoRow(label: 'Condition', value: condition),
          const SizedBox(height: 20),
          if (!_isOwner) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => context.push('/market/${widget.id}/meetup'),
                    child: const Text('Create meetup', style: TextStyle(color: AppTheme.primary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => context.push('/market/${widget.id}/offer-thread'),
                    child: const Text('Send offer'),
                  ),
                ),
              ],
            ),
          ],
          if (_isOwner) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => context.push('/market/${widget.id}/offer-thread'),
                    child: const Text('View offers', style: TextStyle(color: AppTheme.primary)),
                  ),
                ),
                if (statusStr.toLowerCase() != 'sold' && statusStr.toLowerCase() != 'removed') ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => context.push('/market/${widget.id}/mark-sold'),
                      child: const Text('Mark sold'),
                    ),
                  ),
                ],
              ],
            ),
            if (statusStr.toLowerCase() != 'sold' && statusStr.toLowerCase() != 'removed') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                      label: const Text('Edit', style: TextStyle(color: AppTheme.primary)),
                      onPressed: () async {
                        final updated = await context.push('/market/${widget.id}/edit');
                        if (updated == true) _fetchListing();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      label: const Text('Remove', style: TextStyle(color: Colors.red)),
                      onPressed: _confirmRemove,
                    ),
                  ),
                ],
              ),
            ],
          ],
          if (statusStr.toLowerCase() == 'sold') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.star_outline),
                label: const Text('Leave a Review'),
                onPressed: () => _showReviewDialog(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showReviewDialog(BuildContext ctx) async {
    int rating = 5;
    final commentCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: ctx,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Leave a Review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(
                  icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber),
                  onPressed: () => setDialogState(() => rating = i + 1),
                )),
              ),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(hintText: 'Add a comment (optional)'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      try {
        final profileService = ref.read(profileServiceProvider);
        final sellerId = _listing?['seller_id'] as int? ?? 0;
        await profileService.submitReview(
          targetType: 'market',
          targetId: int.tryParse(widget.id) ?? 0,
          revieweeId: sellerId,
          rating: rating,
          comment: commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('Review submitted!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('Failed: ${formatErrorMessage(e)}')),
          );
        }
      }
    }
  }
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.images});
  final List<String> images;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemBuilder: (context, i) {
        final path = images[i];
        final isNetwork = path.startsWith('http');
        final heroTag = '$path-$i';
        return GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (_) => Dialog(
              insetPadding: const EdgeInsets.all(12),
              backgroundColor: Colors.black,
              child: InteractiveViewer(
                child: Hero(
                  tag: heroTag,
                  child: isNetwork
                      ? Image.network(path, fit: BoxFit.contain)
                      : Image.asset(path, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFF7F8FC),
              border: Border.all(color: const Color(0xFFE0E2EB)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Hero(
                tag: heroTag,
                child: isNetwork
                    ? Image.network(path, fit: BoxFit.cover)
                    : Image.asset(path, fit: BoxFit.cover),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E2EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primary,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'S',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
          Text(value, style: const TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }
}

List<String> _extractImages(Map listing, String apiBaseUrl) {
  final photos = listing['photos_paths'] ?? listing['images'];
  if (photos is List && photos.isNotEmpty) {
    return photos.map((e) {
      final path = e.toString();
      if (path.startsWith('http')) return path;
      return '$apiBaseUrl/media/$path';
    }).toList();
  }
  return const [];
}
