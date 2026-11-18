import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';

class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Color? color;
  final Widget? avatar;

  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.color,
    this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.primary;

    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.easeInOut,
      child: ChoiceChip(
        label: Text(label),
        avatar: avatar,
        selected: selected,
        onSelected: onSelected,
        selectedColor: chipColor,
        labelStyle: theme.chipTheme.labelStyle?.copyWith(
          color: selected
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface,
        ),
        backgroundColor: theme.chipTheme.backgroundColor,
        shape: theme.chipTheme.shape,
      ),
    );
  }
}
