import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/post.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/app_button.dart';
import '../../app_router.dart';

enum TrustLevel { verified, trusted, newMember }

extension _TrustLevelExtension on TrustLevel {
  String get label {
    switch (this) {
      case TrustLevel.verified:
        return 'Verified';
      case TrustLevel.trusted:
        return 'Trusted';
      case TrustLevel.newMember:
        return 'New';
    }
  }

  Color get color {
    switch (this) {
      case TrustLevel.verified:
        return AppColors.success;
      case TrustLevel.trusted:
        return AppColors.info;
      case TrustLevel.newMember:
        return AppColors.warning;
    }
  }
}

const Map<String, TrustLevel> _postTrustLevels = {
  'p1': TrustLevel.verified,
  'p2': TrustLevel.verified,
  'p3': TrustLevel.trusted,
  'p4': TrustLevel.newMember,
  'p5': TrustLevel.trusted,
  'p6': TrustLevel.newMember,
};

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'Just now';
}

class CityPulseScreen extends StatefulWidget {
  const CityPulseScreen({super.key});

  @override
  State<CityPulseScreen> createState() => _CityPulseScreenState();
}

class _CityPulseScreenState extends State<CityPulseScreen>
    with SingleTickerProviderStateMixin {
  bool _cityView = true;
  int _unseenCount = 12;
  String _selectedCategory = 'All';
  String? _selectedZone;
  int _bottomIndex = 0;
  final Set<String> _bookmarked = {};
  final TextEditingController _searchController = TextEditingController();
  late final AnimationController _pulseController;

  static const List<String> _categories = [
    'All',
    'Events',
    'Alerts',
    'Meetups',
    'Lost & Found',
    'Recommendations',
  ];

  static const List<String> _zones = ['Downtown', 'Uptown', 'Midtown', 'Suburbs'];

  final List<Post> _posts = [
    Post(
      id: 'p1',
      authorId: 'u1',
      category: 'Events',
      zone: 'Downtown',
      content: 'Community garden cleanup this Saturday at Riverside Park, 9 AM. Gloves and bags provided.',
      isAnonymous: false,
      upvotes: 24,
      bookmarksCount: 3,
      createdAt: DateTime(2026, 11, 17, 14, 30),
      authorName: 'Maya Chen',
      authorHandle: 'mayac',
    ),
    Post(
      id: 'p2',
      authorId: 'u2',
      category: 'Alerts',
      zone: 'Uptown',
      content: 'Water main repair on 5th Avenue. Expect low water pressure between 6th and 8th until 4 PM.',
      isAnonymous: false,
      upvotes: 41,
      bookmarksCount: 7,
      createdAt: DateTime(2026, 11, 17, 11, 15),
      authorName: 'Jordan Lee',
      authorHandle: 'jordanl',
    ),
    Post(
      id: 'p3',
      authorId: 'u3',
      category: 'Lost & Found',
      zone: 'Midtown',
      content: 'Found: orange tabby cat near Central Library, wearing a collar with a tag. Drop off at Midtown vet clinic.',
      isAnonymous: false,
      upvotes: 18,
      bookmarksCount: 2,
      createdAt: DateTime(2026, 11, 17, 9, 0),
      authorName: 'Sam Rivera',
      authorHandle: 'samr',
    ),
    Post(
      id: 'p4',
      authorId: 'u4',
      category: 'Recommendations',
      zone: 'Suburbs',
      content: 'Best coffee roaster in the suburbs? Looking for good espresso and outdoor seating.',
      isAnonymous: false,
      upvotes: 32,
      bookmarksCount: 5,
      createdAt: DateTime(2026, 11, 16, 16, 45),
      authorName: 'Alex Kim',
      authorHandle: 'alexk',
    ),
    Post(
      id: 'p5',
      authorId: 'u5',
      category: 'Meetups',
      zone: 'Downtown',
      content: 'Sunday morning running club. Meet at the clock tower at 7 AM. All paces welcome.',
      isAnonymous: false,
      upvotes: 27,
      bookmarksCount: 4,
      createdAt: DateTime(2026, 11, 16, 12, 0),
      authorName: 'Taylor Brooks',
      authorHandle: 'taylorb',
    ),
    Post(
      id: 'p6',
      authorId: 'u6',
      category: 'Events',
      zone: 'Uptown',
      content: 'Street fair this weekend on Main Street, 11 AM to 8 PM. Local vendors and live music.',
      isAnonymous: true,
      upvotes: 15,
      bookmarksCount: 1,
      createdAt: DateTime(2026, 11, 15, 19, 20),
      authorName: null,
      authorHandle: null,
    ),
  ];

  List<Post> get _filteredPosts {
    final query = _searchController.text.trim().toLowerCase();
    return _posts.where((post) {
      if (!_cityView && _selectedZone != null && post.zone != _selectedZone) {
        return false;
      }
      if (_selectedCategory != 'All' && post.category != _selectedCategory) {
        return false;
      }
      if (query.isNotEmpty) {
        final haystack =
            '${post.category} ${post.zone} ${post.authorName ?? ''} ${post.content}'.toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleArea(bool city) {
    setState(() {
      _cityView = city;
      if (!city) _selectedZone = null;
    });
  }

  void _toggleBookmark(String postId) {
    setState(() {
      if (_bookmarked.contains(postId)) {
        _bookmarked.remove(postId);
      } else {
        _bookmarked.add(postId);
      }
    });
  }

  Future<void> _onRefresh() async {
    await Future<void>.delayed(AppMotion.fast);
    if (!mounted) return;
    setState(() {
      _unseenCount = 0;
    });
  }

  void _onCreatePost() {
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) {
      Navigator.of(context).pushNamed(AppRouter.login);
      return;
    }
    Navigator.of(context).pushNamed(AppRouter.aiCreateSheet);
  }

  Widget _buildUnseenBadge() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            Navigator.of(context).pushNamed(AppRouter.notifications);
            setState(() => _unseenCount = 0);
          },
        ),
        if (_unseenCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: ScaleTransition(
              scale: _pulseController,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowLight.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                child: Text(
                  _unseenCount > 99 ? '99+' : '$_unseenCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAreaSwitch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppChip(
                  label: 'Zone',
                  selected: !_cityView,
                  onSelected: (selected) => _toggleArea(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppChip(
                  label: 'City',
                  selected: _cityView,
                  onSelected: (selected) => _toggleArea(true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedCrossFade(
            duration: AppMotion.normal,
            firstCurve: AppMotion.elastic,
            secondCurve: AppMotion.elastic,
            crossFadeState:
                _cityView ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _zones.map((zone) {
                final selected = _selectedZone == zone;
                return AppChip(
                  label: zone,
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedZone = selected ? null : zone;
                    });
                  },
                );
              }).toList(),
            ),
            secondChild: const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppChip(
                  label: 'All neighborhoods',
                  selected: true,
                  onSelected: null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Ask the city anything...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AppButton(
            text: 'Ask',
            onPressed: () => _searchController.clear(),
            type: AppButtonType.primary,
            width: 88,
          ),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    return Expanded(
      child: RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView.builder(
          itemCount: _filteredPosts.length,
          itemBuilder: (context, index) {
            final post = _filteredPosts[index];
            return PostCard(
              key: ValueKey(post.id),
              post: post,
              isBookmarked: _bookmarked.contains(post.id),
              onBookmarkToggle: () => _toggleBookmark(post.id),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: const Text('City Pulse'),
        centerTitle: true,
        actions: [
          _buildUnseenBadge(),
        ],
      ),
      body: Column(
        children: [
          _buildAreaSwitch(),
          _buildSearchBar(),
          _buildFeed(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onCreatePost,
        child: const Icon(Icons.create),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: (index) => setState(() => _bottomIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_filled),
            label: 'Pulse',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            label: 'Circles',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.isBookmarked,
    this.onBookmarkToggle,
  });

  final Post post;
  final bool isBookmarked;
  final VoidCallback? onBookmarkToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final trust = _postTrustLevels[post.id] ?? TrustLevel.newMember;

    return AppCard(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                imageUrl: null,
                name: post.authorName,
                radius: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          post.authorName ?? 'Anonymous',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _TrustBadge(trust: trust),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _relativeTime(post.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              AppChip(
                label: post.category,
                selected: false,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              AppChip(
                label: post.zone,
                selected: false,
                color: AppColors.amber,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.85),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: isBookmarked ? AppColors.amber : null,
                ),
                onPressed: onBookmarkToggle,
                tooltip: 'Bookmark',
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.comment_outlined),
                onPressed: () {},
                tooltip: 'Comment',
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () {},
                tooltip: 'Share',
              ),
              const Spacer(),
              Text(
                _relativeTime(post.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.trust});

  final TrustLevel trust;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: trust.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: trust.color.withOpacity(0.4),
          width: 0.5,
        ),
      ),
      child: Text(
        trust.label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: trust.color,
        ),
      ),
    );
  }
}
