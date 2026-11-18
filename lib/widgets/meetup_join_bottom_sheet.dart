import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../app_router.dart';
import '../../models/circle.dart';

class MeetupJoinBottomSheet extends StatefulWidget {
  final Circle circle;

  const MeetupJoinBottomSheet({
    super.key,
    required this.circle,
  });

  static Future<void> show(BuildContext context, {required Circle circle}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MeetupJoinBottomSheet(circle: circle),
    );
  }

  @override
  State<MeetupJoinBottomSheet> createState() => _MeetupJoinBottomSheetState();
}

class _MeetupJoinBottomSheetState extends State<MeetupJoinBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final circle = widget.circle;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        circle.title,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _DetailRow(
                  icon: Icons.calendar_today,
                  label: _formatDate(circle.eventDate),
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.access_time,
                  label: _formatTime(circle.eventDate),
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.location_on,
                  label: '${circle.city}, ${circle.zone}',
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Seats Left',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${circle.seatsLeft}',
                        style: textTheme.titleMedium?.copyWith(
                          color: circle.seatsLeft == 0
                              ? colorScheme.error
                              : colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: 'Join Circle',
                  type: AppButtonType.primary,
                  width: double.infinity,
                  onPressed: circle.seatsLeft == 0
                      ? null
                      : () {
                          Navigator.pop(context);
                          Navigator.pushNamed(
                            context,
                            AppRouter.meetupChat,
                            arguments: circle.id,
                          );
                        },
                ),
                const SizedBox(height: 12),
                AppButton(
                  text: 'Share',
                  type: AppButtonType.outline,
                  width: double.infinity,
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 12),
                AppButton(
                  text: 'Cancel',
                  type: AppButtonType.ghost,
                  width: double.infinity,
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
