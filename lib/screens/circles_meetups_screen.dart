import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/circle.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_button.dart';
import '../../app_router.dart';

class CirclesMeetupsScreen extends StatefulWidget {
  const CirclesMeetupsScreen({super.key});

  @override
  State<CirclesMeetupsScreen> createState() => _CirclesMeetupsScreenState();
}

class _CirclesMeetupsScreenState extends State<CirclesMeetupsScreen> {
  final List<Circle> _circles = [
    Circle(
      id: '1',
      title: 'Weekend Coffee Meetup',
      description: 'Casual coffee catch-up for local creators and founders.',
      city: 'Brooklyn',
      zone: 'Downtown',
      creatorId: 'user_1',
      totalSeats: 12,
      seatsLeft: 4,
      isActive: true,
      eventDate: DateTime.now().add(const Duration(days: 3)),
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Circle(
      id: '2',
      title: 'Sunset Running Club',
      description: 'Evening runs along the waterfront, all paces welcome.',
      city: 'Queens',
      zone: 'Astoria',
      creatorId: 'user_2',
      totalSeats: 20,
      seatsLeft: 8,
      isActive: true,
      eventDate: DateTime.now().add(const Duration(days: 5)),
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Circle(
      id: '3',
      title: 'Urban Sketching Circle',
      description: 'Sketch the city together, materials provided.',
      city: 'Manhattan',
      zone: 'Chelsea',
      creatorId: 'user_3',
      totalSeats: 10,
      seatsLeft: 2,
      isActive: true,
      eventDate: DateTime.now().add(const Duration(days: 7)),
      createdAt: DateTime.now(),
    ),
    Circle(
      id: '4',
      title: 'Board Game Night',
      description: 'Weekly strategy and party games at the community hall.',
      city: 'Bronx',
      zone: 'Riverdale',
      creatorId: 'user_4',
      totalSeats: 16,
      seatsLeft: 0,
      isActive: false,
      eventDate: DateTime.now().add(const Duration(days: 2)),
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  void _joinCircle(Circle circle) {
    if (!circle.isActive || circle.seatsLeft <= 0) return;
    Navigator.of(context).pushNamed(AppRouter.meetupChat, arguments: circle);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meetups'),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView.builder(
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
                              '\${circle.city}, \${circle.zone}',
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
                              : colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '\${circle.seatsLeft} seats left',
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            Navigator.of(context).pushNamed(AppRouter.createMeetup),
        child: const Icon(Icons.add),
      ),
    );
  }
}
