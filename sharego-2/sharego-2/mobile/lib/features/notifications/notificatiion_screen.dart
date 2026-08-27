// ignore_for_file: unused_result

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// ignore: unused_import
import 'package:dio/dio.dart';

import '../../core/providers.dart';
import '../../core/app_theme.dart';
import '../common/widgets.dart';

// ============= PROVIDER =============

final notificationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dioClient = ref.watch(dioProvider);
  try {
    final response = await dioClient.get('/notifications');
    final list = response.data as List;
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  } catch (e) {
    throw Exception('Failed to load notifications: $e');
  }
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final dioClient = ref.watch(dioProvider);
  try {
    final response = await dioClient.get('/notifications/unread-count');
    return (response.data['count'] as num).toInt();
  } catch (e) {
    return 0;
  }
});

// ============= NOTIFICATION TILE =============

class NotificationTile extends ConsumerWidget {
  final int id;
  final String title;
  final String body;
  final String? route;
  final DateTime createdAt;
  final bool isRead;

  const NotificationTile({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.route,
    super.key,
  });

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(id.toString()),
      background: Container(
        color: Colors.red.shade100,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete, color: Colors.red.shade700),
      ),
      onDismissed: (_) {
        // TODO: Add delete functionality
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
          color: isRead ? Colors.transparent : AppTheme.primary.withValues(alpha: 0.05),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRead ? Colors.transparent : AppTheme.primary,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _timeAgo(createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
          onTap: isRead
              ? null
              : () async {
                  // Mark as read
                  try {
                    final dioClient = ref.read(dioProvider);
                    await dioClient.post('/notifications/$id/read');
                    ref.refresh(notificationsProvider);
                    ref.refresh(unreadCountProvider);
                  } catch (_) {}

                  // Navigate if route exists
                  if (route != null && route!.isNotEmpty) {
                    context.go(route!);
                  }
                },
        ),
      ),
    );
  }
}

// ============= NOTIFICATION SCREEN =============

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Notifications'),
        actions: [
          notificationsAsync.whenData((notifs) {
            final unread = notifs.where((n) => !n['is_read']).length;
            return unread > 0
                ? TextButton(
                    onPressed: () async {
                      try {
                        final dioClient = ref.read(dioProvider);
                        await dioClient.post('/notifications/read-all');
                        ref.refresh(notificationsProvider);
                        ref.refresh(unreadCountProvider);
                      } catch (_) {}
                    },
                    child: const Text('Mark all as read'),
                  )
                : const SizedBox.shrink();
          }).value ?? const SizedBox.shrink(),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: SkeletonList(items: 5, itemHeight: 80),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load notifications', style: TextStyle(color: Colors.red.shade700)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.refresh(notificationsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'No notifications',
              subtitle: 'You\'re all caught up!',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(notificationsProvider),
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return NotificationTile(
                  id: notif['id'] as int,
                  title: notif['title']?.toString() ?? '',
                  body: notif['body']?.toString() ?? '',
                  route: notif['route']?.toString(),
                  createdAt: DateTime.parse(notif['created_at']?.toString() ?? DateTime.now().toIso8601String()),
                  isRead: notif['is_read'] as bool? ?? false,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ============= NOTIFICATION BADGE WIDGET =============

class NotificationBadge extends ConsumerWidget {
  final Widget child;
  final VoidCallback onPressed;

  const NotificationBadge({
    required this.child,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadCountProvider);

    return Stack(
      children: [
        child,
        unreadAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (count) {
            if (count == 0) return const SizedBox.shrink();
            
            return Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}