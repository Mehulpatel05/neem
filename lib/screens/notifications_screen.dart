import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../app_router.dart';
import '../../models/notification.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _notifications = [
      NotificationItem(
        id: 'n1',
        type: 'like',
        title: 'Liked your post',
        body: 'Alex Kim liked your community garden post.',
        isRead: false,
        createdAt: DateTime(2026, 11, 18, 10, 15),
      ),
      NotificationItem(
        id: 'n2',
        type: 'comment',
        title: 'New comment',
        body: 'Jordan Lee commented on your meetup event.',
        isRead: true,
        createdAt: DateTime(2026, 11, 18, 9, 30),
      ),
      NotificationItem(
        id: 'n3',
        type: 'follow',
        title: 'New follower',
        body: 'Sam Rivera started following you.',
        isRead: false,
        createdAt: DateTime(2026, 11, 17, 16, 45),
      ),
      NotificationItem(
        id: 'n4',
        type: 'mention',
        title: 'Mentioned you',
        body: 'Taylor Brooks mentioned you in a comment.',
        isRead: true,
        createdAt: DateTime(2026, 11, 17, 14, 0),
      ),
      NotificationItem(
        id: 'n5',
        type: 'system',
        title: 'System update',
        body: 'Neem v2.1.0 is now available with new safety features.',
        isRead: false,
        createdAt: DateTime(2026, 11, 16, 11, 0),
      ),
    ];
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  void _markRead(String id) {
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
      }
    });
  }

  void _markAllRead() {
    setState(() {
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    });
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return 'd ago';
    if (diff.inHours > 0) return 'h ago';
    if (diff.inMinutes > 0) return 'm ago';
    return 'Just now';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.chat_bubble_outline;
      case 'follow':
        return Icons.person_add;
      case 'mention':
        return Icons.email;
      case 'system':
        return Icons.info_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _iconColor(String type, ColorScheme colorScheme) {
    switch (type) {
      case 'like':
        return colorScheme.error;
      case 'comment':
        return colorScheme.tertiary;
      case 'follow':
        return colorScheme.secondary;
      case 'mention':
        return colorScheme.secondary;
      case 'system':
        return colorScheme.primary;
      default:
        return colorScheme.primary;
    }
  }

  Widget _buildNotificationItem(NotificationItem notification) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isRead = notification.isRead;

    return AppCard(
      key: ValueKey(notification.id),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      elevation: 1,
      color: isRead ? null : colorScheme.primaryContainer.withOpacity(0.4),
      onTap: () {
        _markRead(notification.id);
        Navigator.of(context).pushNamed(
          AppRouter.postDetail,
          arguments: notification.data,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _iconColor(notification.type, colorScheme).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconForType(notification.type),
                color: _iconColor(notification.type, colorScheme),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _relativeTime(notification.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.75),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isRead
                    ? colorScheme.onSurface.withOpacity(0.3)
                    : colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                return _buildNotificationItem(_notifications[index]);
              },
            ),
    );
  }
}
