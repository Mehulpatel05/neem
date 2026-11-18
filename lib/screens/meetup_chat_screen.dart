import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/app_avatar.dart';
import '../../app_router.dart';

class MeetupChatScreen extends StatefulWidget {
  const MeetupChatScreen({super.key});

  @override
  State<MeetupChatScreen> createState() => _MeetupChatScreenState();
}

class _ChatMessage {
  final String id;
  final String text;
  final String senderName;
  final DateTime timestamp;
  final bool isOwn;

  _ChatMessage({
    required this.id,
    required this.text,
    required this.senderName,
    required this.timestamp,
    required this.isOwn,
  });
}

class _MeetupChatScreenState extends State<MeetupChatScreen> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final String _currentUser = 'You';

  final List<_ChatMessage> _messages = [
    _ChatMessage(
      id: '1',
      text: 'Hey everyone, is the meetup still on for tonight?',
      senderName: 'Alex Rivera',
      timestamp: DateTime(2026, 11, 17, 18, 12),
      isOwn: false,
    ),
    _ChatMessage(
      id: '2',
      text: 'Yes, see you at 7 PM at the cafe.',
      senderName: 'You',
      timestamp: DateTime(2026, 11, 17, 18, 15),
      isOwn: true,
    ),
    _ChatMessage(
      id: '3',
      text: 'Awesome, I will bring snacks.',
      senderName: 'Sam Chen',
      timestamp: DateTime(2026, 11, 17, 18, 20),
      isOwn: false,
    ),
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(
        _ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          senderName: _currentUser,
          timestamp: DateTime.now(),
          isOwn: true,
        ),
      );
      _textController.clear();
    });
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: AppMotion.fast,
      curve: Curves.easeOut,
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOwn = message.isOwn;

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isOwn
              ? colorScheme.primary
              : colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isOwn) ...[
                    AppAvatar(
                      name: message.senderName,
                      radius: 14,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      message.senderName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isOwn
                            ? colorScheme.onPrimary.withOpacity(0.8)
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('h:mm a').format(message.timestamp),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isOwn
                          ? colorScheme.onPrimary.withOpacity(0.6)
                          : colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isOwn
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Chat'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
              reverse: false,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceVariant,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: colorScheme.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send, size: 20),
                      color: colorScheme.onPrimary,
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
