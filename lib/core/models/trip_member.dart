import 'package:hive/hive.dart';

part 'trip_member.g.dart';

/// One person sharing a trip.
///
/// Members belong to the trip, not to the People tab. A trip has to keep
/// working when somebody is renamed or removed from People, and two people can
/// legitimately share a name, so a member is identified by [id] rather than by
/// their name. Expenses and settlements reference that id; the name is only ever
/// presentation.
@HiveType(typeId: 9)
class TripMember extends HiveObject {
  /// Stable within its trip, and the key expenses and settlements use.
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  /// Optional — a trip is just as valid with nothing but names.
  @HiveField(2)
  String? phone;

  @HiveField(3)
  String? email;

  /// A short qualifier for two members who share a name ("Aman's cousin"), so a
  /// person can tell them apart without inventing a different name.
  @HiveField(4)
  String? label;

  TripMember({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.label,
  });

  /// How this member reads in a list: the label when there is one, so two
  /// "Rahul"s are never shown identically.
  String get displayName =>
      (label == null || label!.trim().isEmpty) ? name : '$name (${label!.trim()})';

  /// Names match when they differ only by surrounding space or letter case,
  /// which is how people actually retype a name they have already added.
  static bool namesMatch(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'label': label,
      };
}
