import 'package:meta/meta.dart';

class Post {
  final String id;
  final String authorId;
  final String category;
  final String zone;
  final String content;
  final bool isAnonymous;
  final int upvotes;
  final int bookmarksCount;
  final DateTime createdAt;
  final String? authorName;
  final String? authorHandle;

  Post({
    required this.id,
    required this.authorId,
    required this.category,
    required this.zone,
    required this.content,
    required this.isAnonymous,
    required this.upvotes,
    required this.bookmarksCount,
    required this.createdAt,
    this.authorName,
    this.authorHandle,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      authorId: json['authorId'] as String,
      category: json['category'] as String,
      zone: json['zone'] as String,
      content: json['content'] as String,
      isAnonymous: json['isAnonymous'] as bool,
      upvotes: json['upvotes'] as int,
      bookmarksCount: json['bookmarksCount'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      authorName: json['authorName'] as String?,
      authorHandle: json['authorHandle'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorId': authorId,
      'category': category,
      'zone': zone,
      'content': content,
      'isAnonymous': isAnonymous,
      'upvotes': upvotes,
      'bookmarksCount': bookmarksCount,
      'createdAt': createdAt.toIso8601String(),
      'authorName': authorName,
      'authorHandle': authorHandle,
    };
  }

  Post copyWith({
    String? id,
    String? authorId,
    String? category,
    String? zone,
    String? content,
    bool? isAnonymous,
    int? upvotes,
    int? bookmarksCount,
    DateTime? createdAt,
    String? authorName,
    String? authorHandle,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      category: category ?? this.category,
      zone: zone ?? this.zone,
      content: content ?? this.content,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      upvotes: upvotes ?? this.upvotes,
      bookmarksCount: bookmarksCount ?? this.bookmarksCount,
      createdAt: createdAt ?? this.createdAt,
      authorName: authorName ?? this.authorName,
      authorHandle: authorHandle ?? this.authorHandle,
    );
  }
}
