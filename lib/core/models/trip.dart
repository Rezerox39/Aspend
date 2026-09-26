import 'package:hive/hive.dart';

part 'trip.g.dart';

/// A group trip: a named, date-bounded container that several people share
/// expenses within.
///
/// Members are stored by **name** rather than as references to `Person`, for
/// the same reason `PersonTransaction` stores `personName` — a trip has to
/// survive its members being renamed or removed from the People tab, and
/// looking a member up by name keeps the two features independent.
@HiveType(typeId: 6)
class Trip extends HiveObject {
  @HiveField(0)
  String name;

  /// Where the trip goes — shown under the title on the trip card.
  @HiveField(1)
  String? destination;

  @HiveField(2)
  DateTime startDate;

  /// Null while a trip is still open-ended (an ongoing trip has no end yet).
  @HiveField(3)
  DateTime? endDate;

  /// Names of the people sharing this trip.
  @HiveField(4)
  List<String> memberNames;

  @HiveField(6)
  String? coverPhotoPath;

  @HiveField(7)
  String? notes;

  /// Archived trips are hidden from the default list but keep all history.
  @HiveField(8)
  bool isArchived;

  @HiveField(9)
  DateTime createdAt;

  Trip({
    required this.name,
    required this.startDate,
    required List<String> memberNames,
    this.destination,
    this.endDate,
    this.coverPhotoPath,
    this.notes,
    this.isArchived = false,
    DateTime? createdAt,
  })  : memberNames = List<String>.from(memberNames),
        createdAt = createdAt ?? DateTime.now();

  bool get isOngoing => endDate == null || endDate!.isAfter(DateTime.now());

  Map<String, dynamic> toJson() => {
        'name': name,
        'destination': destination,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'memberNames': memberNames,
        'coverPhotoPath': coverPhotoPath,
        'notes': notes,
        'isArchived': isArchived,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        name: json['name'] as String,
        destination: json['destination'] as String?,
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: json['endDate'] == null
            ? null
            : DateTime.parse(json['endDate'] as String),
        memberNames: List<String>.from(json['memberNames'] as List),
        coverPhotoPath: json['coverPhotoPath'] as String?,
        notes: json['notes'] as String?,
        isArchived: json['isArchived'] as bool? ?? false,
        createdAt: json['createdAt'] == null
            ? DateTime.now()
            : DateTime.parse(json['createdAt'] as String),
      );
}
