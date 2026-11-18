import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/app_providers.dart';
import '../../core/auth/auth_service.dart';
import '../../app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/app_button.dart';

class InterestPickerScreen extends StatefulWidget {
  const InterestPickerScreen({super.key});

  @override
  State<InterestPickerScreen> createState() => _InterestPickerScreenState();
}

class _InterestPickerScreenState extends State<InterestPickerScreen> {
  static const int _maxSelections = 3;

  static const List<String> _interests = [
    'Food',
    'Tech',
    'Sports',
    'Music',
    'Art',
    'Travel',
    'Fitness',
    'Books',
    'Movies',
    'Gaming',
    'Outdoors',
    'Fashion',
  ];

  final Set<String> _selected = {};

  void _toggleInterest(String interest) {
    setState(() {
      if (_selected.contains(interest)) {
        _selected.remove(interest);
      } else if (_selected.length < _maxSelections) {
        _selected.add(interest);
      }
    });
  }

  Future<void> _onContinue() async {
    if (_selected.length != _maxSelections) return;
    final AuthService authService =
        context.read<AuthNotifier>().authService;
    await authService.saveInterests(_selected.toList());
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRouter.cityPulse);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What interests you?',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick 3 things to personalize your feed',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _interests.map((interest) {
                    final selected = _selected.contains(interest);
                    return AppChip(
                      label: interest,
                      selected: selected,
                      color: AppColors.primary,
                      onSelected: (_) => _toggleInterest(interest),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: AppButton(
                text: 'Continue',
                onPressed:
                    _selected.length == _maxSelections ? _onContinue : null,
                type: AppButtonType.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
