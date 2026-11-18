import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../network/api_client.dart';

class InAppUpdateService {
  static const int currentVersionCode = 1;
  static const String currentVersionName = '1.0.0';

  static Future<void> checkForUpdate(
    BuildContext context, {
    bool showNoUpdateToast = false,
  }) async {
    try {
      final info = await ApiClient.checkAppUpdate();
      if (info == null) {
        if (showNoUpdateToast && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to check for updates right now'),
            ),
          );
        }
        return;
      }

      final latestCode = (info['versionCode'] as num?)?.toInt() ?? 1;
      final latestName = info['latestVersion']?.toString() ?? currentVersionName;
      final updateUrl = info['updateUrl']?.toString() ??
          info['downloadUrl']?.toString() ??
          'http://43.204.215.17/storage/updates/neem-latest.apk';
      final releaseNotes = info['releaseNotes']?.toString() ??
          'New improvements and bug fixes are available.';
      final forceUpdate = info['forceUpdate'] == true;

      final hasUpdate = latestCode > currentVersionCode ||
          (latestName.isNotEmpty && latestName != currentVersionName);

      if (hasUpdate && context.mounted) {
        _showUpdateDialog(
          context,
          versionName: latestName,
          releaseNotes: releaseNotes,
          updateUrl: updateUrl,
          forceUpdate: forceUpdate,
        );
      } else if (showNoUpdateToast && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are using the latest version of Neem!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (_) {
      if (showNoUpdateToast && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to check for updates right now'),
          ),
        );
      }
    }
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String versionName,
    required String releaseNotes,
    required String updateUrl,
    required bool forceUpdate,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) => PopScope(
        canPop: !forceUpdate,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.system_update, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              const Text('Update Available'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A new version (v$versionName) is ready to install.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  releaseNotes,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Later'),
              ),
            ElevatedButton(
              onPressed: () async {
                final uri = Uri.parse(updateUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }
}
