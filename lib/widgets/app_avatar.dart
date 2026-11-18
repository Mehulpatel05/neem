import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';

class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final Widget? child;
  final String? name;
  final String? heroTag;

  const AppAvatar({
    super.key,
    this.imageUrl,
    this.radius = 24,
    this.backgroundColor,
    this.onTap,
    this.child,
    this.name,
    this.heroTag,
  });

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  Widget _buildPlaceholder() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceVariantLight,
      child: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildFallback() {
    if (child != null) return child!;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppColors.primary,
      child: Text(
        _initials(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = imageUrl != null && imageUrl!.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: imageUrl!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildPlaceholder(),
            errorWidget: (context, url, error) => _buildFallback(),
          )
        : _buildFallback();

    final widget = heroTag != null && heroTag!.isNotEmpty
        ? Hero(tag: heroTag!, child: avatar)
        : avatar;

    final bordered = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.dividerLight,
          width: 2,
        ),
      ),
      child: ClipOval(child: widget),
    );

    if (onTap == null) return bordered;
    return GestureDetector(
      onTap: onTap,
      child: bordered,
    );
  }
}
