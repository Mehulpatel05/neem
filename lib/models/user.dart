import 'dart:convert';

class User {
  final String id;
  final String phoneNumber;
  final String displayName;
  final String? handle;
  final String city;
  final String zone;
  final List<String> interests;
  final int trustScore;
  final String? avatarUrl;
  final bool isAnonymous;
  final DateTime createdAt;

  User({
    required this.id,
    required this.phoneNumber,
    required this.displayName,
    this.handle,
    required this.city,
    required this.zone,
    required this.interests,
    required this.trustScore,
    this.avatarUrl,
    required this.isAnonymous,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      phoneNumber: json['phoneNumber'] as String,
      displayName: json['displayName'] as String,
      handle: json['handle'] as String?,
      city: json['city'] as String,
      zone: json['zone'] as String,
      interests: List<String>.from(json['interests'] as List<dynamic>),
      trustScore: json['trustScore'] as int,
      avatarUrl: json['avatarUrl'] as String?,
      isAnonymous: json['isAnonymous'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'handle': handle,
      'city': city,
      'zone': zone,
      'interests': interests,
      'trustScore': trustScore,
      'avatarUrl': avatarUrl,
      'isAnonymous': isAnonymous,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? phoneNumber,
    String? displayName,
    String? handle,
    String? city,
    String? zone,
    List<String>? interests,
    int? trustScore,
    String? avatarUrl,
    bool? isAnonymous,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      handle: handle ?? this.handle,
      city: city ?? this.city,
      zone: zone ?? this.zone,
      interests: interests ?? this.interests,
      trustScore: trustScore ?? this.trustScore,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
