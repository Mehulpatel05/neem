import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';

enum AppButtonType { primary, outline, ghost, danger }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final bool isLoading;
  final double? width;
  final double? height;
  final IconData? icon;

  final ValueNotifier<double> _scale = ValueNotifier(1.0);

  AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.width,
    this.height,
    this.icon,
  });

  Color _textColor() {
    switch (type) {
      case AppButtonType.primary:
      case AppButtonType.danger:
        return AppColors.onPrimaryLight;
      case AppButtonType.outline:
      case AppButtonType.ghost:
        return AppColors.primary;
    }
  }

  Color _fillColor() {
    switch (type) {
      case AppButtonType.primary:
        return AppColors.primary;
      case AppButtonType.danger:
        return AppColors.error;
      case AppButtonType.outline:
      case AppButtonType.ghost:
        return Colors.transparent;
    }
  }

  Border? _border() {
    switch (type) {
      case AppButtonType.outline:
        return Border.all(color: AppColors.primary);
      case AppButtonType.primary:
      case AppButtonType.danger:
      case AppButtonType.ghost:
        return null;
    }
  }

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _enabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTapDown: (_) {
          if (_enabled) _scale.value = 0.95;
        },
        onTapUp: (_) => _scale.value = 1.0,
        onTapCancel: () => _scale.value = 1.0,
        onTap: _enabled ? onPressed : null,
        child: ValueListenableBuilder<double>(
          valueListenable: _scale,
          builder: (context, scale, child) {
            return AnimatedScale(
              scale: scale,
              duration: AppMotion.fast,
              curve: AppMotion.easeOut,
              child: AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.easeOut,
                width: width,
                height: height ?? 50,
                decoration: BoxDecoration(
                  color: _fillColor(),
                  border: _border(),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: type == AppButtonType.primary ||
                          type == AppButtonType.danger
                      ? [
                          BoxShadow(
                            color: AppColors.shadowLight.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: _buildContent(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(AppColors.onPrimaryLight),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, color: _textColor(), size: 20),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: TextStyle(
            color: _textColor(),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
