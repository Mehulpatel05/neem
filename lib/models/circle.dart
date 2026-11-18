class Circle {
  final String id;
  final String title;
  final String description;
  final String city;
  final String zone;
  final String creatorId;
  final int totalSeats;
  final int seatsLeft;
  final bool isActive;
  final DateTime eventDate;
  final DateTime createdAt;

  Circle({
    required this.id,
    required this.title,
    required this.description,
    required this.city,
    required this.zone,
    required this.creatorId,
    required this.totalSeats,
    required this.seatsLeft,
    required this.isActive,
    required this.eventDate,
    required this.createdAt,
  });

  factory Circle.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is DateTime) return d;
      try {
        return DateTime.parse(d.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    return Circle(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      zone: json['zone']?.toString() ?? '',
      creatorId: json['creatorId']?.toString() ?? json['creator_id']?.toString() ?? '',
      totalSeats: (json['totalSeats'] ?? json['total_seats'] ?? 10) as int,
      seatsLeft: (json['seatsLeft'] ?? json['seats_left'] ?? 0) as int,
      isActive: json['isActive'] == true || json['is_active'] == 1,
      eventDate: parseDate(json['eventDate'] ?? json['event_date']),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'city': city,
      'zone': zone,
      'creatorId': creatorId,
      'totalSeats': totalSeats,
      'seatsLeft': seatsLeft,
      'isActive': isActive,
      'eventDate': eventDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Circle copyWith({
    String? id,
    String? title,
    String? description,
    String? city,
    String? zone,
    String? creatorId,
    int? totalSeats,
    int? seatsLeft,
    bool? isActive,
    DateTime? eventDate,
    DateTime? createdAt,
  }) {
    return Circle(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      city: city ?? this.city,
      zone: zone ?? this.zone,
      creatorId: creatorId ?? this.creatorId,
      totalSeats: totalSeats ?? this.totalSeats,
      seatsLeft: seatsLeft ?? this.seatsLeft,
      isActive: isActive ?? this.isActive,
      eventDate: eventDate ?? this.eventDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
