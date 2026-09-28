import 'package:hive/hive.dart';

import 'trip_member.dart';

part 'trip.g.dart';

/// A group trip: a named, date-bounded container that several people share
/// expenses within.
///
/// Members live on the trip ([members]) rather than being borrowed from the
/// People tab, so removing somebody from People can never rewrite a trip's
/// history. [memberNames] is kept as a mirror of [members] because older data
/// and several widgets still read it, and a trip that has never been migrated
/// still carries its members there.
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

  /// Names of the people sharing this trip. Mirrors [members]; kept in sync by
  /// [syncMemberNames] and still the only place a never-migrated trip records
  /// its members.
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

  /// The currency every balance in this trip is settled in.
  ///
  /// Expenses may be entered in whatever currency was actually paid; the rate
  /// typed at that point converts them into this one. Keeping one currency per
  /// trip is what lets a settle-up reach exactly zero instead of drifting.
  @HiveField(10)
  String baseCurrency;

  /// The trip's people. Empty until the trip is migrated or a member is added.
  @HiveField(11)
  List<TripMember> members;

  Trip({
    required this.name,
    required this.startDate,
    required List<String> memberNames,
    this.destination,
    this.endDate,
    this.coverPhotoPath,
    this.notes,
    this.isArchived = false,
    this.baseCurrency = 'INR',
    List<TripMember>? members,
    DateTime? createdAt,
  })  : memberNames = List<String>.from(memberNames),
        members = List<TripMember>.from(members ?? const []),
        createdAt = createdAt ?? DateTime.now();

  bool get isOngoing => endDate == null || endDate!.isAfter(DateTime.now());

  /// Member ids, which is what expenses and settlements key on.
  List<String> get memberIds => members.map((m) => m.id).toList();

  /// Members as a trip sees them, whether they came from [members] or from the
  /// [memberNames] of a trip created before members existed.
  List<TripMember> get effectiveMembers => members.isNotEmpty
      ? members
      : memberNames.map((n) => TripMember(id: n, name: n)).toList();

  /// Looks up a member by id, falling back to the trip's effective members.
  TripMember? memberById(String id) {
    for (final member in effectiveMembers) {
      if (member.id == id) return member;
    }
    return null;
  }

  /// The member whose id or name is [key]. Balances and settle-up are keyed by
  /// id, but a trip that predates members may still key by name.
  TripMember? memberByKey(String key) {
    for (final member in effectiveMembers) {
      if (member.id == key) return member;
    }
    for (final member in effectiveMembers) {
      if (TripMember.namesMatch(member.name, key)) return member;
    }
    return null;
  }

  /// The display name for a balance or settlement key, falling back to the key
  /// itself so an unmapped entry is still shown rather than blank.
  String nameOf(String key) => memberByKey(key)?.displayName ?? key;

  /// A member already on the trip under this name, if any.
  TripMember? findMemberByName(String candidate) {
    for (final member in members) {
      if (TripMember.namesMatch(member.name, candidate)) return member;
    }
    return null;
  }

  /// Adds a person to the trip, refusing a name that is already on it.
  ///
  /// Returns the member that ended up in the trip: the existing one when the
  /// name was a duplicate, so a caller can select it rather than creating a
  /// second "Rahul" by accident.
  TripMember addMember(String candidate, {String? phone, String? email, String? label}) {
    final existing = findMemberByName(candidate);
    if (existing != null) return existing;
    final member = TripMember(
      id: memberIdFor(candidate),
      name: candidate.trim(),
      phone: (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
      email: (email == null || email.trim().isEmpty) ? null : email.trim(),
      label: (label == null || label.trim().isEmpty) ? null : label.trim(),
    );
    members.add(member);
    syncMemberNames();
    return member;
  }

  void removeMember(String id) {
    members.removeWhere((m) => m.id == id);
    syncMemberNames();
  }

  /// Mirrors [members] back into [memberNames] so anything still reading the
  /// legacy list sees the same people.
  void syncMemberNames() {
    memberNames = members.map((m) => m.name).toList();
  }

  /// Ids have to stay stable once expenses reference them, so they are derived
  /// from the name rather than regenerated each time. That is what makes the
  /// migration safe to re-run: the same name always yields the same id, on any
  /// device, in any session, so a second pass can never re-key stored expenses.
  ///
  /// The readable stem is not enough on its own. It keeps only `[a-z0-9]`, so
  /// "José" and "Jos" both reduce to `jos` — two different people who [addMember]
  /// happily accepts, because their names are not duplicates. Sharing an id
  /// would merge their balances into one person and quietly lose money at
  /// settle-up. A hash of the whole name rides along so distinct names stay
  /// distinct, and it is what keeps non-Latin names (which reduce to an empty
  /// stem) apart from one another.
  static String memberIdFor(String candidate) {
    final normalized = candidate.trim().toLowerCase();
    final stem = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '');
    final readable = stem.isEmpty ? 'm' : 'm$stem';
    return '$readable-${_shortHash(normalized).toRadixString(36)}';
  }

  /// A cheap, stable 31-bit string hash. Deterministic across runs and
  /// platforms, which is all an id disambiguator needs.
  static int _shortHash(String value) {
    var hash = 7;
    for (final rune in value.runes) {
      hash = (hash * 31 + rune) & 0x7fffffff;
    }
    return hash;
  }

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
        'baseCurrency': baseCurrency,
        'members': members.map((m) => m.toJson()).toList(),
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
        baseCurrency: (json['baseCurrency'] as String?) ?? 'INR',
        members: [
          // Promoted once instead of cast five times per member. A malformed
          // entry is skipped rather than throwing on the whole trip.
          for (final raw in (json['members'] as List? ?? const []))
            if (raw is Map)
              TripMember(
                id: raw['id'] as String,
                name: raw['name'] as String,
                phone: raw['phone'] as String?,
                email: raw['email'] as String?,
                label: raw['label'] as String?,
              ),
        ],
        createdAt: json['createdAt'] == null
            ? DateTime.now()
            : DateTime.parse(json['createdAt'] as String),
      );
}
