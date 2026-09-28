import 'package:aspends_tracker/core/models/trip.dart';
import 'package:aspends_tracker/core/models/trip_member.dart';
import 'package:flutter_test/flutter_test.dart';

/// Members are identified by id rather than by name, so the tests here are
/// mostly about the one guarantee the rest of the feature leans on: a name must
/// always map to the same id, and two different people must never share one.
Trip _trip(List<String> memberNames, {List<TripMember>? members}) => Trip(
      name: 'Test trip',
      startDate: DateTime(2026, 1, 1),
      memberNames: memberNames,
      members: members,
    );

void main() {
  group('member ids', () {
    test('are derived from the name, so they survive a restart', () {
      final id = Trip.memberIdFor('Rahul');

      expect(Trip.memberIdFor('Rahul'), id);
      expect(Trip.memberIdFor('  RAHUL  '), id,
          reason: 'ids must ignore the case and spacing addMember treats as a '
              'duplicate name, or the same person would get two ids');
    });

    test('stay distinct for names that share a stem', () {
      // "José" and "Jos" both reduce to the ASCII stem "jos". They are not
      // duplicates, so they must not collapse onto one id — a shared id would
      // merge two people's balances and quietly lose money at settle-up.
      expect(Trip.memberIdFor('José'), isNot(Trip.memberIdFor('Jos')));
      expect(Trip.memberIdFor('Raman'), isNot(Trip.memberIdFor('Raman!')));
    });

    test('stay distinct for non-Latin names, which have no ASCII stem', () {
      expect(Trip.memberIdFor('राहुल'), isNot(Trip.memberIdFor('राहुल जी')));
      expect(Trip.memberIdFor('🎉'), isNot(Trip.memberIdFor('😀')));
    });

    test('is readable enough to debug with', () {
      expect(Trip.memberIdFor('Rahul'), startsWith('mrahul-'));
    });
  });

  group('addMember', () {
    test('reuses the existing member for a duplicate name', () {
      final trip = _trip(const []);
      final first = trip.addMember('Rahul');
      final again = trip.addMember('  rahul ');

      expect(identical(again, first), isTrue);
      expect(trip.members, hasLength(1),
          reason: 'a retyped name must select the member, not add a second one');
    });

    test('keeps memberNames in step for the legacy read sites', () {
      final trip = _trip(const []);
      trip.addMember('Ana');
      trip.addMember('Ben');

      expect(trip.memberNames, ['Ana', 'Ben']);
    });

    test('stops listing a removed member in memberNames', () {
      final trip = _trip(const []);
      final ana = trip.addMember('Ana');
      trip.addMember('Ben');
      trip.removeMember(ana.id);

      expect(trip.memberNames, ['Ben']);
    });
  });

  group('two members sharing a name', () {
    Trip sameNamed() => _trip(
          const ['Rahul', 'Rahul'],
          members: [
            TripMember(id: 'one', name: 'Rahul', label: 'phone'),
            TripMember(id: 'two', name: 'Rahul', label: 'work'),
          ],
        );

    test('stay separately addressable by id', () {
      final trip = sameNamed();

      expect(trip.members, hasLength(2));
      expect(trip.memberById('one')!.label, 'phone');
      expect(trip.memberById('two')!.label, 'work');
    });

    test('read differently on screen', () {
      final trip = sameNamed();

      expect(trip.nameOf('one'), 'Rahul (phone)');
      expect(trip.nameOf('two'), 'Rahul (work)');
    });
  });

  group('trips created before members existed', () {
    test('fall back to their names so nothing disappears mid-upgrade', () {
      final legacy = _trip(const ['Ana', 'Ben']);

      expect(legacy.members, isEmpty);
      expect(legacy.effectiveMembers.map((m) => m.id), ['Ana', 'Ben']);
      expect(legacy.nameOf('Ana'), 'Ana');
    });

    test('resolve a balance keyed by an already-migrated id', () {
      final trip = _trip(
        const ['Ana', 'Ben'],
        members: [
          TripMember(id: 'm-1', name: 'Ana'),
          TripMember(id: 'm-2', name: 'Ben'),
        ],
      );

      expect(trip.nameOf('m-1'), 'Ana');
      expect(trip.nameOf('m-2'), 'Ben');
    });
  });

  group('nameOf', () {
    test('falls back to the key so an unknown entry is still shown', () {
      final trip = _trip(const ['Ana']);

      expect(trip.nameOf('who-dis'), 'who-dis');
    });
  });
}
