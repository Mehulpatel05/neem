import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/providers/app_providers.dart';
import '../../core/auth/auth_service.dart';
import '../../app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
    _checkAuth();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(AppMotion.slower);
    if (!mounted) return;

    final authNotifier = context.read<AuthNotifier>();
    final isAuthenticated = await authNotifier.tryRestoreSession();

    if (!mounted || _navigating) return;
    _navigating = true;

    if (isAuthenticated) {
      Navigator.of(context).pushReplacementNamed(AppRouter.cityPulse);
    } else {
      Navigator.of(context).pushReplacementNamed(AppRouter.login);
    }
  }

  bool _isJwtValid(String? token) {
    if (token == null || token.isEmpty) return false;
    final parts = token.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = base64Url.decode(
        parts[1].replaceAll('-', '+').replaceAll('_', '/'),
      );
      final map = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
      final exp = map['exp'] as num?;
      if (exp == null) return true;
      return DateTime.fromMillisecondsSinceEpoch((exp as num).toInt() * 1000)
          .isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Neem',
                  style: GoogleFonts.poppins(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Neem - Your City, Your Community',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
