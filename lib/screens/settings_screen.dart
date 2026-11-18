import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/auth/auth_service.dart';
import '../../app_router.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _smartPersonalization = true;
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _smsNotifications = false;
  bool _saveOfflineContent = true;
  bool _autoDownloadMedia = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final authNotifier = Provider.of<AuthNotifier>(context, listen: false);

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: const Text('Settings & Privacy'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          _SectionHeader(title: 'Appearance'),
          SwitchListTile.adaptive(
            title: const Text('Dark mode'),
            subtitle: const Text('Switch between light and dark themes'),
            value: themeNotifier.isDarkMode,
            onChanged: (_) => themeNotifier.toggleTheme(),
            secondary: Icon(
              themeNotifier.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: colorScheme.primary,
            ),
          ),
          const Divider(height: 1),

          _SectionHeader(title: 'Personalization'),
          SwitchListTile.adaptive(
            title: const Text('Smart Personalization'),
            subtitle: const Text('Interest-based feed and recommendations'),
            value: _smartPersonalization,
            onChanged: (value) => setState(() => _smartPersonalization = value),
            secondary: Icon(
              Icons.auto_awesome,
              color: AppColors.primary,
            ),
          ),
          const Divider(height: 1),

          _SectionHeader(title: 'Notification Preferences'),
          SwitchListTile.adaptive(
            title: const Text('Push notifications'),
            subtitle: const Text('Receive real-time updates and alerts'),
            value: _pushNotifications,
            onChanged: (value) => setState(() => _pushNotifications = value),
            secondary: Icon(
              Icons.notifications_outlined,
              color: AppColors.primary,
            ),
          ),
          SwitchListTile.adaptive(
            title: const Text('Email notifications'),
            subtitle: const Text('Daily and weekly digests via email'),
            value: _emailNotifications,
            onChanged: (value) => setState(() => _emailNotifications = value),
            secondary: Icon(
              Icons.email_outlined,
              color: AppColors.primary,
            ),
          ),
          SwitchListTile.adaptive(
            title: const Text('SMS notifications'),
            subtitle: const Text('Critical alerts via text message'),
            value: _smsNotifications,
            onChanged: (value) => setState(() => _smsNotifications = value),
            secondary: Icon(
              Icons.sms_outlined,
              color: AppColors.primary,
            ),
          ),
          const Divider(height: 1),

          _SectionHeader(title: 'Data & Storage'),
          SwitchListTile.adaptive(
            title: const Text('Save offline content'),
            subtitle: const Text('Cache posts and media for offline viewing'),
            value: _saveOfflineContent,
            onChanged: (value) => setState(() => _saveOfflineContent = value),
            secondary: Icon(
              Icons.save_outlined,
              color: AppColors.primary,
            ),
          ),
          SwitchListTile.adaptive(
            title: const Text('Auto-download media'),
            subtitle: const Text('Download images and videos on Wi-Fi'),
            value: _autoDownloadMedia,
            onChanged: (value) => setState(() => _autoDownloadMedia = value),
            secondary: Icon(
              Icons.download_outlined,
              color: AppColors.primary,
            ),
          ),
          ListTile(
            title: const Text('Clear cache'),
            subtitle: const Text('Remove cached images and files'),
            trailing: Icon(Icons.delete_outline, color: AppColors.error),
            onTap: () => _showClearCacheDialog(context),
          ),
          const Divider(height: 1),

          _SectionHeader(title: 'Account'),
          ListTile(
            title: const Text('Delete Account'),
            subtitle: const Text('Permanently delete your account and data'),
            trailing: Icon(Icons.delete_forever, color: AppColors.error),
            onTap: () => _showDeleteAccountDialog(context, authNotifier),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _handleLogout(context, authNotifier),
            child: const Text('Logout'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, AuthNotifier authNotifier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await authNotifier.logout();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.login,
          (route) => false,
        );
      }
    }
  }

  Future<void> _showDeleteAccountDialog(
    BuildContext context,
    AuthNotifier authNotifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action is permanent. Your profile, posts, and all associated '
          'data will be deleted and cannot be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await authNotifier.logout();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.login,
          (route) => false,
        );
      }
    }
  }

  Future<void> _showClearCacheDialog(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('Remove cached images and files?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8, left: 4, right: 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
    );
  }
}
