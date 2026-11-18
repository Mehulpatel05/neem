import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/auth/auth_service.dart';
import '../../core/providers/app_providers.dart';
import '../../app_router.dart';

class ProfileMenuBottomSheet extends StatefulWidget {
  const ProfileMenuBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ProfileMenuBottomSheet(),
    );
  }

  @override
  State<ProfileMenuBottomSheet> createState() => _ProfileMenuBottomSheetState();
}

class _ProfileMenuBottomSheetState extends State<ProfileMenuBottomSheet> {
  final List<_MenuItem> _items = const [
    _MenuItem('View Profile', Icons.person_outline, '/profile', false),
    _MenuItem('Edit Profile', Icons.edit_outlined, '/edit-profile', false),
    _MenuItem('My Bookmarks', Icons.bookmark_outline, '/bookmarks', false),
    _MenuItem('My Circles', Icons.people_outline, '/circles', false),
    _MenuItem('Settings', Icons.settings_outlined, AppRouter.settings, false),
    _MenuItem('Logout', Icons.logout, AppRouter.login, true),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            ..._items.map((item) => _buildItem(context, item)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, _MenuItem item) {
    final theme = Theme.of(context);
    final isDestructive = item.isDestructive;

    return ListTile(
      leading: Icon(
        item.icon,
        color: isDestructive ? AppColors.error : theme.colorScheme.onSurface,
        size: 24,
      ),
      title: Text(
        item.title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: isDestructive ? AppColors.error : theme.colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () => _onItemTap(context, item),
    );
  }

  Future<void> _onItemTap(BuildContext context, _MenuItem item) async {
    Navigator.pop(context);
    final navigator = Navigator.of(context);

    if (item.isDestructive) {
      await context.read<AuthNotifier>().authService.logout();
      if (!mounted) return;
      navigator.pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
      return;
    }

    if (!mounted) return;
    navigator.pushNamed(item.route);
  }
}

class _MenuItem {
  const _MenuItem(this.title, this.icon, this.route, this.isDestructive);

  final String title;
  final IconData icon;
  final String route;
  final bool isDestructive;
}
