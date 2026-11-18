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
    return Circle(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      city: json['city'] as String,
      zone: json['zone'] as String,
      creatorId: json['creatorId'] as String,
      totalSeats: json['totalSeats'] as int,
      seatsLeft: json['seatsLeft'] as int,
      isActive: json['isActive'] as bool,
      eventDate: DateTime.parse(json['eventDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
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
