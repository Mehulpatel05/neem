import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_button.dart';
import '../../app_router.dart';
import '../../models/message.dart';
import '../../models/user.dart';

class SafeChatScreen extends StatefulWidget {
  final User? partner;

  const SafeChatScreen({super.key, this.partner});

  @override
  State<SafeChatScreen> createState() => _SafeChatScreenState();
}

class _SafeChatScreenState extends State<SafeChatScreen> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final String _currentUserId = 'current-user';

  bool _isRecording = false;
  int _voiceSeconds = 0;
  Timer? _voiceTimer;

  User? get _partner =>
      widget.partner ?? (ModalRoute.of(context)?.settings.arguments as User?);

  String? _playingMessageId;

  final List<Message> _messages = [
    Message(
      id: '1',
      conversationId: 'safe-1',
      senderId: 'partner',
      content: 'Hey there! How is your day going?',
      type: 'text',
      mediaUrl: null,
      createdAt: DateTime(2026, 11, 17, 18, 5),
    ),
    Message(
      id: '2',
      conversationId: 'safe-1',
      senderId: 'current-user',
      content: "It's going well, thanks! How about yours?",
      type: 'text',
      mediaUrl: null,
      createdAt: DateTime(2026, 11, 17, 18, 7),
    ),
    Message(
      id: '3',
      conversationId: 'safe-1',
      senderId: 'partner',
      content: '6',
      type: 'voice',
      mediaUrl: 'https://example.com/voice-3.aac',
      createdAt: DateTime(2026, 11, 17, 18, 9),
    ),
  ];

  @override
  void dispose() {
    _voiceTimer?.cancel();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppMotion.fast,
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(
        Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          conversationId: 'safe-1',
          senderId: _currentUserId,
          content: text,
          type: 'text',
          mediaUrl: null,
          createdAt: DateTime.now(),
        ),
      );
      _textController.clear();
    });
    _scrollToBottom();
  }

  void _toggleRecording() {
    if (_isRecording) {
      _voiceTimer?.cancel();
      setState(() {
        _isRecording = false;
        if (_voiceSeconds > 0) {
          _messages.add(
            Message(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              conversationId: 'safe-1',
              senderId: _currentUserId,
              content: _voiceSeconds.toString(),
              type: 'voice',
              mediaUrl: 'https://example.com/voice-${DateTime.now().millisecondsSinceEpoch}.aac',
              createdAt: DateTime.now(),
            ),
          );
        }
        _voiceSeconds = 0;
      });
      _scrollToBottom();
    } else {
      setState(() {
        _isRecording = true;
        _voiceSeconds = 0;
      });
      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _voiceSeconds++);
      });
    }
  }

  void _attachImage() {
    setState(() {
      _messages.add(
        Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          conversationId: 'safe-1',
          senderId: _currentUserId,
          content: 'Image',
          type: 'image',
          mediaUrl: 'https://example.com/image-${DateTime.now().millisecondsSinceEpoch}.jpg',
          createdAt: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  void _togglePlayback(String messageId) {
    setState(() {
      _playingMessageId = _playingMessageId == messageId ? null : messageId;
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }

  Widget _buildMessageBubble(Message message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOwn = message.senderId == _currentUserId;
    final partnerName = _partner?.displayName ?? 'Partner';
    final partnerAvatar = _partner?.avatarUrl;

    return Column(
      crossAxisAlignment:
          isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (!isOwn)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Row(
              children: [
                AppAvatar(
                  name: partnerName,
                  imageUrl: partnerAvatar,
                  radius: 14,
                ),
                const SizedBox(width: 8),
                Text(
                  partnerName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        Align(
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
                        Text(
                          partnerName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isOwn
                                ? colorScheme.onPrimary.withOpacity(0.8)
                                : colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        DateFormat('h:mm a').format(message.createdAt),
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
                  _buildMessageContent(message, theme, colorScheme, isOwn),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageContent(
    Message message,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isOwn,
  ) {
    switch (message.type) {
      case 'image':
        return GestureDetector(
          onTap: () => _showImagePreview(message),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              message.mediaUrl ?? '',
              height: 160,
              width: 160,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 160,
                width: 160,
                color: colorScheme.surfaceVariant,
                child: const Icon(Icons.broken_image, size: 40),
              ),
            ),
          ),
        );
      case 'voice':
        final isPlaying = _playingMessageId == message.id;
        final duration = int.tryParse(message.content) ?? 0;
        return GestureDetector(
          onTap: () => _togglePlayback(message.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isOwn
                  ? colorScheme.primary.withOpacity(0.85)
                  : colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPlaying ? Icons.stop : Icons.play_circle,
                  size: 20,
                  color: isOwn
                      ? colorScheme.onPrimary
                      : colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(duration),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isOwn
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      case 'text':
      default:
        return Text(
          message.content,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isOwn
                ? colorScheme.onPrimary
                : colorScheme.onSurface,
          ),
        );
    }
  }

  void _showImagePreview(Message message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              message.mediaUrl ?? '',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image, size: 60),
            ),
            const SizedBox(height: 12),
            AppButton(
              text: 'Close',
              type: AppButtonType.ghost,
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final partnerName = _partner?.displayName ?? 'Partner';
    final partnerHandle = _partner?.handle;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              partnerName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (partnerHandle != null && partnerHandle.isNotEmpty)
              Text(
                '@$partnerHandle',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 11,
                ),
              ),
          ],
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
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
                  AppButton(
                    text: '',
                    type: AppButtonType.ghost,
                    icon: Icons.image_outlined,
                    onPressed: _attachImage,
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    text: '',
                    type: _isRecording ? AppButtonType.danger : AppButtonType.ghost,
                    icon: _isRecording ? Icons.stop : Icons.mic,
                    onPressed: _toggleRecording,
                  ),
                  const SizedBox(width: 8),
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
                      onSubmitted: (_) => _sendTextMessage(),
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    text: '',
                    type: AppButtonType.primary,
                    icon: Icons.send,
                    width: 44,
                    height: 44,
                    onPressed: _sendTextMessage,
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
