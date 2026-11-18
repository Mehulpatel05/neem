import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/circle.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_button.dart';
import '../../app_router.dart';
import '../../core/network/api_client.dart';

class CirclesMeetupsScreen extends StatefulWidget {
  final bool isEmbedded;
  const CirclesMeetupsScreen({super.key, this.isEmbedded = false});

  @override
  State<CirclesMeetupsScreen> createState() => _CirclesMeetupsScreenState();
}

class _CirclesMeetupsScreenState extends State<CirclesMeetupsScreen> {
  List<Circle> _circles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCircles();
  }

  Future<void> _fetchCircles() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.get('/api/v1/circles');
      final list = res is Map ? (res['circles'] as List?) : (res is List ? res : null);
      if (list != null && mounted) {
        setState(() {
          _circles = list
              .map((item) => Circle.fromJson(item as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _circles = [];
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _joinCircle(Circle circle) {
    if (!circle.isActive || circle.seatsLeft <= 0) return;
    Navigator.of(context).pushNamed(AppRouter.meetupChat, arguments: circle);
  }

  Widget _buildContent(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _fetchCircles,
      child: _circles.isEmpty
          ? ListView(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.groups_outlined,
                          size: 72,
                          color: colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No circles or meetups yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Host a coffee hangout, run club, or study group in your neighborhood!',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.of(context)
                                .pushNamed(AppRouter.createMeetup);
                            _fetchCircles();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Meetup'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _circles.length,
              itemBuilder: (context, index) {
                final circle = _circles[index];
                final canJoin = circle.isActive && circle.seatsLeft > 0;

                return AppCard(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  circle.title,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${circle.city}, ${circle.zone}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: canJoin
                                  ? colorScheme.primary.withOpacity(0.1)
                                  : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${circle.seatsLeft} seats left',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: canJoin
                                    ? colorScheme.primary
                                    : colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        circle.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: AppButton(
                          text: 'Join Circle',
                          type: AppButtonType.outline,
                          onPressed: canJoin ? () => _joinCircle(circle) : null,
                          width: 120,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.isEmbedded) {
      return _buildContent(theme, colorScheme);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meetups & Circles'),
        elevation: 0,
      ),
      body: SafeArea(
        child: _buildContent(theme, colorScheme),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).pushNamed(AppRouter.createMeetup);
          _fetchCircles();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
