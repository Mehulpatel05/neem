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
import '../../core/network/api_client.dart';
import 'circles_meetups_screen.dart';
import 'profile_saved_screen.dart';

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
  int _unseenCount = 0;
  String _selectedCategory = 'All';
  String? _selectedZone;
  int _bottomIndex = 0;
  final Set<String> _bookmarked = {};
  final TextEditingController _searchController = TextEditingController();
  late final AnimationController _pulseController;

  List<Post> _posts = [];
  bool _isLoading = false;

  static const List<String> _categories = [
    'All',
    'Events',
    'Alerts',
    'Meetups',
    'Lost & Found',
    'Recommendations',
  ];

  static const List<String> _zones = ['Downtown', 'Uptown', 'Midtown', 'Suburbs'];

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
            '${post.category} ${post.zone} ${post.authorName ?? ''} ${post.content}'
                .toLowerCase();
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
    _fetchPosts();
    _fetchUnreadNotifications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchPosts() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.get('/api/v1/posts');
      final list =
          res is Map ? (res['posts'] as List?) : (res is List ? res : null);
      if (list != null && mounted) {
        setState(() {
          _posts = list
              .map((item) => Post.fromJson(item as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _posts = []);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUnreadNotifications() async {
    try {
      final res = await ApiClient.get('/api/v1/notifications');
      final list =
          res is Map ? (res['notifications'] as List?) : (res is List ? res : null);
      if (list != null && mounted) {
        final unread = list.where((item) => item['isRead'] != true && item['is_read'] != 1).length;
        setState(() => _unseenCount = unread);
      }
    } catch (_) {}
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
    await _fetchPosts();
    await _fetchUnreadNotifications();
  }

  void _showManualCreatePostSheet() {
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) {
      Navigator.of(context).pushNamed(AppRouter.login);
      return;
    }

    final currentUser = auth.currentUser;
    final defaultZone = currentUser?['zone'] ?? 'Downtown';
    final defaultCity = currentUser?['city'] ?? 'Local';

    final contentCtrl = TextEditingController();
    final zoneCtrl = TextEditingController(text: defaultZone);
    String selectedCat = 'Events';
    bool isAnonymous = false;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Create New Post',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentCtrl,
                      maxLines: 4,
                      maxLength: 280,
                      decoration: const InputDecoration(
                        hintText: "What's happening in your neighborhood?",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Category',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _categories
                          .where((c) => c != 'All')
                          .map((cat) {
                        final isSel = selectedCat == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) setSheetState(() => selectedCat = cat);
                          },
                          selectedColor: const Color(0xFF2E7D32),
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : Colors.black87,
                            fontSize: 12,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: zoneCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Neighborhood / Zone',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Post anonymously'),
                      subtitle: const Text('Hide your name and profile'),
                      value: isAnonymous,
                      onChanged: (val) => setSheetState(() => isAnonymous = val),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final text = contentCtrl.text.trim();
                              if (text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter post content'),
                                  ),
                                );
                                return;
                              }

                              setSheetState(() => isSubmitting = true);
                              try {
                                await ApiClient.post('/api/v1/posts', body: {
                                  'content': text,
                                  'category': selectedCat,
                                  'zone': zoneCtrl.text.trim().isEmpty
                                      ? defaultZone
                                      : zoneCtrl.text.trim(),
                                  'city': defaultCity,
                                  'isAnonymous': isAnonymous,
                                });

                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }

                                if (mounted) {
                                  setState(() => _bottomIndex = 0);
                                  _fetchPosts();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Post published successfully!'),
                                      backgroundColor: Color(0xFF2E7D32),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() => isSubmitting = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to post: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Publish Post',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUnseenBadge() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () async {
            await Navigator.of(context).pushNamed(AppRouter.notifications);
            _fetchUnreadNotifications();
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
                      color: AppColors.shadowLight.withValues(alpha: 0.4),
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
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search neighborhood posts...',
                prefixIcon: Icon(Icons.search),
                filled: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: _categories.map((cat) {
          final isSel = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSel,
              onSelected: (val) {
                if (val) setState(() => _selectedCategory = cat);
              },
              selectedColor: const Color(0xFF2E7D32),
              labelStyle: TextStyle(
                color: isSel ? Colors.white : Colors.black87,
                fontSize: 12,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPulseFeed() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _filteredPosts.isEmpty
            ? ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No posts found',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Be the first neighbor to post an update, alert, or recommendation!',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _showManualCreatePostSheet,
                            icon: const Icon(Icons.add),
                            label: const Text('Create Post'),
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

  Widget _buildPulseView() {
    return Column(
      children: [
        _buildAreaSwitch(),
        _buildSearchBar(),
        _buildCategoryRow(),
        const SizedBox(height: 8),
        _buildPulseFeed(),
      ],
    );
  }

  String _getTitleForTab() {
    switch (_bottomIndex) {
      case 0:
        return 'City Pulse';
      case 1:
        return 'Meetups & Circles';
      case 2:
        return 'My Profile & Storage';
      default:
        return 'Neem';
    }
  }

  List<Widget> _getActionsForTab() {
    if (_bottomIndex == 0) {
      return [_buildUnseenBadge()];
    } else if (_bottomIndex == 1) {
      return [
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => Navigator.of(context).pushNamed(AppRouter.createMeetup),
          tooltip: 'Create Meetup',
        ),
      ];
    } else {
      return [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).pushNamed(AppRouter.settings),
          tooltip: 'Settings',
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(_getTitleForTab()),
        centerTitle: true,
        actions: _getActionsForTab(),
      ),
      body: IndexedStack(
        index: _bottomIndex,
        children: [
          _buildPulseView(),
          const CirclesMeetupsScreen(isEmbedded: true),
          const ProfileSavedScreen(isEmbedded: true),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showManualCreatePostSheet,
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        tooltip: 'Create Post',
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: (index) => setState(() => _bottomIndex = index),
        selectedItemColor: const Color(0xFF2E7D32),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_filled),
            label: 'Pulse',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups),
            label: 'Circles',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
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
    final trust = post.upvotes > 20
        ? TrustLevel.verified
        : (post.upvotes > 5 ? TrustLevel.trusted : TrustLevel.newMember);

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
                          post.authorName ?? 'Anonymous Neighbor',
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
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
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
              color: colorScheme.onSurface.withValues(alpha: 0.85),
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
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    AppRouter.postDetail,
                    arguments: post,
                  );
                },
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
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
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
        color: trust.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: trust.color.withValues(alpha: 0.4),
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
