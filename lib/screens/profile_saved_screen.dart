import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/app_providers.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_chip.dart';
import '../../app_router.dart';
import '../../models/user.dart';
import '../../models/post.dart';

class ProfileSavedScreen extends StatefulWidget {
  const ProfileSavedScreen({super.key});

  @override
  State<ProfileSavedScreen> createState() => _ProfileSavedScreenState();
}

class _ProfileSavedScreenState extends State<ProfileSavedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final User _user = User(
    id: 'user_1',
    phoneNumber: '+1 555 0123',
    displayName: 'Alex Rivera',
    handle: '@alex.r',
    city: 'Brooklyn',
    zone: 'Downtown',
    interests: const ['Food', 'Music', 'Art'],
    trustScore: 92,
    avatarUrl: 'https://i.pravatar.cc/150?u=alex',
    isAnonymous: false,
    createdAt: DateTime(2023, 5, 12),
  );

  final List<Post> _bookmarks = [
    Post(
      id: 'post_1',
      authorId: 'user_2',
      category: 'Food',
      zone: 'Downtown',
      content: 'Best tacos in the city, hands down.',
      isAnonymous: false,
      upvotes: 142,
      bookmarksCount: 87,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      authorName: 'Jamie Lin',
      authorHandle: '@jamie.l',
    ),
    Post(
      id: 'post_2',
      authorId: 'user_3',
      category: 'Music',
      zone: 'Williamsburg',
      content: 'Live jazz at the waterfront this weekend.',
      isAnonymous: false,
      upvotes: 98,
      bookmarksCount: 54,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      authorName: 'Sam Ortiz',
      authorHandle: '@sam.o',
    ),
    Post(
      id: 'post_3',
      authorId: 'user_4',
      category: 'Art',
      zone: 'DUMBO',
      content: 'New mural opened on Front Street.',
      isAnonymous: true,
      upvotes: 210,
      bookmarksCount: 132,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Post(
      id: 'post_4',
      authorId: 'user_5',
      category: 'Food',
      zone: 'Downtown',
      content: 'Hidden speakeasy with great small plates.',
      isAnonymous: false,
      upvotes: 67,
      bookmarksCount: 41,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      authorName: 'Taylor Kim',
      authorHandle: '@taylor.k',
    ),
  ];

  final List<_Circle> _circles = [
    _Circle(
      id: 'circle_1',
      title: 'Weekend Coffee Meetup',
      city: 'Brooklyn',
      zone: 'Downtown',
      memberCount: 24,
    ),
    _Circle(
      id: 'circle_2',
      title: 'Sunset Running Club',
      city: 'Queens',
      zone: 'Astoria',
      memberCount: 31,
    ),
    _Circle(
      id: 'circle_3',
      title: 'Urban Sketching Circle',
      city: 'Manhattan',
      zone: 'Chelsea',
      memberCount: 18,
    ),
  ];

  final List<_Badge> _badges = [
    _Badge(
      icon: Icons.verified,
      title: 'Trusted Member',
      subtitle: 'Consistently helpful contributions',
      color: AppColors.primary,
    ),
    _Badge(
      icon: Icons.star,
      title: 'Top Contributor',
      subtitle: 'Top 10% of posters this month',
      color: AppColors.amber,
    ),
    _Badge(
      icon: Icons.shield,
      title: 'Community Guardian',
      subtitle: 'Helped moderate 50+ reports',
      color: AppColors.info,
    ),
    _Badge(
      icon: Icons.local_fire_department,
      title: 'Hot Streak',
      subtitle: 'Posted daily for 7 days',
      color: AppColors.warning,
    ),
  ];

  List<dynamic> _r2Files = [];
  bool _isLoadingFiles = false;
  String? _storageError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCloudFiles();
  }

  Future<void> _loadCloudFiles() async {
    setState(() => _isLoadingFiles = true);
    try {
      final files = await ApiClient.listUserFiles();
      if (mounted) {
        setState(() {
          _r2Files = files;
          _isLoadingFiles = false;
          _storageError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFiles = false;
          _storageError = e.toString();
        });
      }
    }
  }

  Future<void> _syncToCloud() async {
    final authNotifier = context.read<AuthNotifier>();
    final user = authNotifier.currentUser;
    if (user != null) {
      try {
        await ApiClient.saveUserData(user);
        await _loadCloudFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile synced to your Cloud R2 folder!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sync error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _goToSettings() {
    Navigator.of(context).pushNamed(AppRouter.settings);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _goToSettings,
            tooltip: 'Edit profile',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme, colorScheme),
            const SizedBox(height: 16),
            _buildTabBar(theme, colorScheme),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBookmarksTab(theme, colorScheme),
                  _buildCirclesTab(theme, colorScheme),
                  _buildBadgesTab(theme, colorScheme),
                  _buildCloudFilesTab(theme, colorScheme),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToSettings,
        label: const Text('Edit Profile'),
        icon: const Icon(Icons.person_outline),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    final currentUser = context.watch<AuthNotifier>().currentUser;
    final displayName = currentUser?['displayName'] ?? currentUser?['name'] ?? _user.displayName;
    final handle = currentUser?['handle'] ?? _user.handle ?? '';
    final city = currentUser?['city'] ?? _user.city ?? 'Local';
    final zone = currentUser?['zone'] ?? _user.zone ?? 'Community';
    final avatarUrl = currentUser?['avatarUrl'] ?? _user.avatarUrl;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          AppAvatar(
            imageUrl: avatarUrl,
            name: displayName,
            radius: 44,
          ),
          const SizedBox(height: 12),
          Text(
            displayName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            handle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppChip(
                label: 'Trust ${_user.trustScore}',
                avatar: const Icon(
                  Icons.shield,
                  size: 16,
                  color: Colors.white,
                ),
                color: _user.trustScore >= 80
                    ? AppColors.success
                    : colorScheme.primary,
                selected: true,
              ),
              const SizedBox(width: 12),
              AppChip(
                label: '$city, $zone',
                avatar: const Icon(
                  Icons.location_on,
                  size: 16,
                  color: Colors.white,
                ),
                color: colorScheme.primary,
                selected: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _goToSettings,
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Edit Profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.onSurface,
                side: BorderSide(color: colorScheme.outlineVariant),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme, ColorScheme colorScheme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: colorScheme.primary,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurface.withOpacity(0.5),
        labelStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'Bookmarks'),
          Tab(text: 'My Circles'),
          Tab(text: 'Trust Badges'),
          Tab(text: 'My Cloud Files'),
        ],
      ),
    );
  }

  Widget _buildBookmarksTab(ThemeData theme, ColorScheme colorScheme) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.78,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final post = _bookmarks[index];
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: colorScheme.surfaceVariant.withOpacity(0.5),
                    child: Center(
                      child: Icon(
                        Icons.bookmark_border,
                        color: colorScheme.onSurface.withOpacity(0.4),
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              AppChip(
                label: post.category,
                color: colorScheme.primary,
                selected: false,
              ),
              const SizedBox(height: 8),
              Text(
                post.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.thumb_up,
                    size: 16,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.upvotes}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.bookmark,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.bookmarksCount}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCirclesTab(ThemeData theme, ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _circles.length,
      itemBuilder: (context, index) {
        final circle = _circles[index];
        return AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: AppAvatar(
              name: circle.title,
              radius: 24,
              backgroundColor: colorScheme.primary.withOpacity(0.15),
            ),
            title: Text(
              circle.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              '${circle.city}, ${circle.zone}  \u00b7  ${circle.memberCount} members',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            trailing: AppChip(
              label: 'Joined',
              color: AppColors.success,
              selected: true,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadgesTab(ThemeData theme, ColorScheme colorScheme) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.05,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _badges.length,
      itemBuilder: (context, index) {
        final badge = _badges[index];
        return AppCard(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: badge.color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  badge.icon,
                  color: badge.color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                badge.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                badge.subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCloudFilesTab(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoadingFiles) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My R2 Cloud Storage (${_r2Files.length})',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadCloudFiles,
                    tooltip: 'Refresh files',
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_upload, size: 16),
                    label: const Text('Sync Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _syncToCloud,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_storageError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_storageError!, style: const TextStyle(color: Colors.red)),
            ),
          if (_r2Files.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.folder_open, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    'Your dedicated R2 folder is ready: users/{userId}/',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap Sync Profile above to save your profile into your private R2 folder.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _r2Files.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final file = _r2Files[index];
                final key = file['key']?.toString() ?? '';
                final size = file['size'] ?? 0;
                final filename = key.split('/').last;
                final parts = key.split('/');
                final folder = parts.length > 2 ? parts[parts.length - 2] : 'root';

                return ListTile(
                  tileColor: colorScheme.surfaceVariant.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  leading: Icon(
                    folder == 'data'
                        ? Icons.data_object
                        : folder == 'audio'
                            ? Icons.audiotrack
                            : Icons.insert_drive_file,
                    color: AppColors.primary,
                  ),
                  title: Text(filename, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('$key • ${(size / 1024).toStringAsFixed(1)} KB'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      await ApiClient.deleteUserFile(key);
                      _loadCloudFiles();
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Circle {
  final String id;
  final String title;
  final String city;
  final String zone;
  final int memberCount;

  _Circle({
    required this.id,
    required this.title,
    required this.city,
    required this.zone,
    required this.memberCount,
  });
}

class _Badge {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  _Badge({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}
