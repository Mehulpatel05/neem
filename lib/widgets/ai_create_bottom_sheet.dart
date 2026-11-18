import 'dart:io';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../app_router.dart';

class AICreateBottomSheet extends StatefulWidget {
  const AICreateBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AICreateBottomSheet(),
    );
  }

  @override
  State<AICreateBottomSheet> createState() => _AICreateBottomSheetState();
}

class _AICreateBottomSheetState extends State<AICreateBottomSheet> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isRecording = false;
  bool _isAnonymous = false;
  bool _isStructuring = false;
  bool _isPosting = false;
  String? _error;
  String? _recordedPath;
  String _selectedCategory = 'General';

  static const List<String> _categories = [
    'General',
    'Advice',
    'Vent',
    'Question',
    'Story',
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        if (mounted) {
          setState(() {
            _isRecording = false;
            _recordedPath = path;
          });
        }
      } else {
        final hasPermission = await _audioRecorder.hasPermission();
        if (!hasPermission) {
          if (mounted) setState(() => _error = 'Microphone permission is required');
          return;
        }
        final path =
            '${Directory.systemTemp.path}/neem_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        if (mounted) {
          setState(() {
            _isRecording = true;
            _error = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _error = 'Voice recording failed: $e';
        });
      }
    }
  }

  Future<void> _structureWithAI() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Please type or record something first');
      return;
    }
    setState(() {
      _isStructuring = true;
      _error = null;
    });
    try {
      final response = await ApiClient.post(
        '/api/v1/ai/structure-post',
        body: {'text': text, 'language': 'hinglish'},
      );
      _titleController.text = (response['title'] ?? '').toString();
      _contentController.text = (response['content'] ?? '').toString();
      final category = (response['category'] ?? 'General').toString();
      if (_categories.contains(category)) {
        _selectedCategory = category;
      }
      if (mounted) setState(() => _isStructuring = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isStructuring = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _post() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      setState(() => _error = 'Title and content are required');
      return;
    }
    setState(() {
      _isPosting = true;
      _error = null;
    });
    try {
      await ApiClient.post(
        '/api/v1/posts',
        body: {
          'title': title,
          'category': _selectedCategory,
          'content': content,
          'isAnonymous': _isAnonymous,
        },
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post published successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPosting = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Create with AI',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceLight,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Speak or type in Hinglish or your regional language',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.onSurfaceLight.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _inputController,
                    hint: "What's on your mind?",
                    maxLines: 3,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: _isRecording ? AppColors.error : AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.white),
                    iconSize: 24,
                    padding: const EdgeInsets.all(14),
                    onPressed: _toggleRecording,
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            AppButton(
              text: 'Structure with AI',
              icon: Icons.auto_awesome,
              isLoading: _isStructuring,
              onPressed: _structureWithAI,
              width: double.infinity,
            ),
            const SizedBox(height: 20),
            if (_titleController.text.isNotEmpty || _contentController.text.isNotEmpty) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Structured Preview',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceLight,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _titleController,
                      label: 'Title',
                    ),
                    const SizedBox(height: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariantLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.dividerLight),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        items: _categories
                            .map((category) => DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _selectedCategory = value);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _contentController,
                      label: 'Content',
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            SwitchListTile(
              title: const Text(
                'Post anonymously',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              value: _isAnonymous,
              onChanged: (value) => setState(() => _isAnonymous = value),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 16),
            AppButton(
              text: 'Post',
              icon: Icons.send,
              isLoading: _isPosting,
              onPressed: _post,
              width: double.infinity,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
