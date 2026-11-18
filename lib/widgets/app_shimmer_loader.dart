import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';

class AppShimmerLoader extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Color baseColor;
  final Color highlightColor;

  const AppShimmerLoader({
    super.key,
    required this.child,
    required this.isLoading,
    this.baseColor = AppColors.surfaceVariantLight,
    this.highlightColor = Colors.white,
  });

  @override
  State<AppShimmerLoader> createState() => _AppShimmerLoaderState();
}

class _AppShimmerLoaderState extends State<AppShimmerLoader> {
  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    return Shimmer.fromColors(
      baseColor: widget.baseColor,
      highlightColor: widget.highlightColor,
      child: widget.child,
    );
  }
}
