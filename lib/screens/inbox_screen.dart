import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/app_avatar.dart';
import '../../app_router.dart';
import '../../models/message.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _Conversation {
  final String id;
  final String name;
  final String? avatarUrl;
  final Message lastMessage;
  final DateTime timestamp;
  final int unreadCount;

  _Conversation({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.lastMessage,
    required this.timestamp,
    this.unreadCount = 0,
  });
}

class _InboxScreenState extends State<InboxScreen> {
  final List<_Conversation> _conversations = [
    _Conversation(
      id: 'c1',
      name: 'Alex Rivera',
      avatarUrl: null,
      lastMessage: Message(
        id: 'm1',
        conversationId: 'c1',
        senderId: 'u2',
        content: 'Are we still on for tonight?',
        type: 'text',
        createdAt: DateTime(2026, 11, 17, 20, 15),
      ),
      timestamp: DateTime(2026, 11, 17, 20, 15),
      unreadCount: 2,
    ),
    _Conversation(
      id: 'c2',
      name: 'Sam Chen',
      avatarUrl: null,
      lastMessage: Message(
        id: 'm2',
        conversationId: 'c2',
        senderId: 'u3',
        content: 'Awesome, I will bring snacks.',
        type: 'text',
        createdAt: DateTime(2026, 11, 17, 18, 20),
      ),
      timestamp: DateTime(2026, 11, 17, 18, 20),
      unreadCount: 0,
    ),
    _Conversation(
      id: 'c3',
      name: 'Jordan Lee',
      avatarUrl: null,
      lastMessage: Message(
        id: 'm3',
        conversationId: 'c3',
        senderId: 'u4',
        content: 'See you at the cafe at 7 PM.',
        type: 'text',
        createdAt: DateTime(2026, 11, 16, 14, 30),
      ),
      timestamp: DateTime(2026, 11, 16, 14, 30),
      unreadCount: 1,
    ),
    _Conversation(
      id: 'c4',
      name: 'Taylor Kim',
      avatarUrl: null,
      lastMessage: Message(
        id: 'm4',
        conversationId: 'c4',
        senderId: 'u5',
        content: 'Thanks for the meetup invite.',
        type: 'text',
        createdAt: DateTime(2026, 11, 15, 10, 5),
      ),
      timestamp: DateTime(2026, 11, 15, 10, 5),
      unreadCount: 0,
    ),
  ];

  void _openChat(String conversationId) {
    Navigator.of(context).pushNamed(
      AppRouter.safeChat,
      arguments: conversationId,
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final isToday =
        now.year == time.year &&
        now.month == time.month &&
        now.day == time.day;
    if (isToday) {
      return DateFormat('h:mm a').format(time);
    }
    return DateFormat('MMM d').format(time);
  }

  Widget _buildConversationItem(_Conversation conversation) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasUnread = conversation.unreadCount > 0;

    return ListTile(
      leading: AppAvatar(
        imageUrl: conversation.avatarUrl,
        name: conversation.name,
        radius: 24,
      ),
      title: Text(
        conversation.name,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: hasUnread ? colorScheme.primary : colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        conversation.lastMessage.content,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface.withOpacity(0.7),
          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTime(conversation.timestamp),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasUnread) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    conversation.unreadCount.toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      onTap: () => _openChat(conversation.id),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
      ),
      body: ListView.builder(
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          return _buildConversationItem(_conversations[index]);
        },
      ),
    );
  }
}
