import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/ui/smart_tree/entity_formatter_registry.dart';

void main() {
  group('EntityFormatterRegistry', () {
    test('returns null for empty map', () {
      expect(EntityFormatterRegistry.tryFormat({}), isNull);
    });

    group('Address heuristic', () {
      test('matches german address keys', () {
        final map = {
          'strasse': 'Hauptstrasse 1',
          'plz': '1010',
          'ort': 'Wien',
          'land': 'AT',
        };
        final result = EntityFormatterRegistry.tryFormat(map);
        expect(result, isNotNull);
        expect(result!.icon, Icons.location_on_outlined);
        expect(result.label, 'Hauptstrasse 1, 1010 Wien');
        expect(result.color, Colors.blueAccent);
      });

      test('matches english address keys with case insensitivity', () {
        final map = {
          'Street': '5th Avenue',
          'Zip': '10001',
          'City': 'New York',
        };
        final result = EntityFormatterRegistry.tryFormat(map);
        expect(result, isNotNull);
        expect(result!.label, '5th Avenue, 10001 New York');
      });

      test('formats address when only city is provided', () {
        final map = {'city': 'Berlin'};
        final result = EntityFormatterRegistry.tryFormat(map);
        expect(result, isNotNull);
        expect(result!.label, 'Berlin');
      });
    });

    group('Date/Time window heuristic', () {
      test('matches startDate and endDate with ISO formatting', () {
        final map = {
          'startDate': '2026-09-24T08:00:00Z',
          'endDate': '2026-09-26T18:00:00Z',
        };
        final result = EntityFormatterRegistry.tryFormat(map);
        expect(result, isNotNull);
        expect(result!.icon, Icons.date_range_outlined);
        expect(result.label, '2026-09-24 → 2026-09-26');
        expect(result.color, Colors.orangeAccent);
      });

      test('matches validFrom and validTo', () {
        final map = {
          'validFrom': '2026-01-01',
          'validTo': '2026-12-31',
        };
        final result = EntityFormatterRegistry.tryFormat(map);
        expect(result, isNotNull);
        expect(result!.label, '2026-01-01 → 2026-12-31');
      });
    });

    group('Geo coordinates heuristic', () {
      test('matches lat and lon', () {
        final map = {
          'lat': 48.2082,
          'lon': 16.3738,
        };
        final result = EntityFormatterRegistry.tryFormat(map);
        expect(result, isNotNull);
        expect(result!.icon, Icons.pin_drop_outlined);
        expect(result.label, '48.2082, 16.3738');
        expect(result.color, Colors.green);
      });

      test('matches latitude and longitude', () {
        final map = {
          'latitude': 52.5200,
          'longitude': 13.4050,
        };
        final result = EntityFormatterRegistry.tryFormat(map);
        expect(result, isNotNull);
        expect(result!.label, '52.52, 13.405');
      });
    });

    group('Generic compact flat object heuristic', () {
      test('formats object with id and name keys compactly', () {
        final map = {
          'id': 1042,
          'name': 'Acme Corp',
        };
        final result = EntityFormatterRegistry.tryFormat(map);
        expect(result, isNotNull);
        expect(result!.icon, Icons.data_object);
        expect(result.label, '1042 • Acme Corp');
        expect(result.color, Colors.teal);
      });

      test('formats object with id, name, and third attribute', () {
        final map = {
          'id': 'C-99',
          'name': 'VIP Customer',
          'tier': 1,
        };
        final result = EntityFormatterRegistry.tryFormat(map);
        expect(result, isNotNull);
        expect(result!.label, 'C-99 • VIP Customer (tier: 1)');
      });

      test('does not format single-entry object as generic composite badge', () {
        final map = {'status': 'ACTIVE'};
        final result = EntityFormatterRegistry.tryFormat(map);
        expect(result, isNull);
      });

      test('formats generic 3-4 entry flat object without id/name', () {
        final map = {
          'code': 'XYZ',
          'priority': 2,
          'active': true,
        };
        final result = EntityFormatterRegistry.tryFormat(map);
        expect(result, isNotNull);
        expect(result!.label, contains('code: XYZ'));
        expect(result.label, contains('priority: 2'));
        expect(result.label, contains('active: true'));
      });

      test('rejects map containing nested map or list', () {
        final map = {
          'id': 1,
          'details': {'nested': true},
        };
        final result = EntityFormatterRegistry.tryFormat(map);
        expect(result, isNull);
      });

      test('rejects map with string values exceeding length limit', () {
        final map = {
          'id': 1,
          'description': 'a' * 60, // > 50 chars
        };
        final result = EntityFormatterRegistry.tryFormat(map);
        expect(result, isNull);
      });

      test('rejects flat map with more than 4 non-null entries', () {
        final map = {
          'k1': 1,
          'k2': 2,
          'k3': 3,
          'k4': 4,
          'k5': 5,
        };
        final result = EntityFormatterRegistry.tryFormat(map);
        expect(result, isNull);
      });

      test('formats map with 5 keys where 3 are null or empty list', () {
        final map = {
          'art': 'Eintritt',
          'id': '02440ff5-bb63-f9cf-82da-61b70b0f28e9',
          'kundenauftragsId': null,
          'kundenauftragsMeilensteinIds': [],
          'trailerKennzeichen': null,
        };
        final result = EntityFormatterRegistry.tryFormat(map);
        expect(result, isNotNull);
        expect(result!.label, contains('Eintritt'));
        expect(result.label, contains('02440ff5-bb63-f9cf-82da-61b70b0f28e9'));
      });
    });

    group('Extended heuristics (nested time, standalone timestamp, routes)', () {
      test('formats nested timestamp object for planTimestampVon and planTimestampBis', () {
        final map = {
          'planTimestampVon': {
            'timestamp': '2026-09-29T05:00:00+01:00',
            'zeitQuelle': 'SYSTEM'
          },
          'planTimestampBis': {
            'timestamp': '2026-09-29T19:00:00+01:00',
            'zeitQuelle': 'SYSTEM'
          },
        };
        final result = EntityFormatterRegistry.tryFormat(map);
        expect(result, isNotNull);
        expect(result!.icon, Icons.date_range_outlined);
        expect(result.label, contains('2026-09-29'));
        expect(result.label, contains('→'));
      });

      test('formats standalone timestamp with metadata', () {
        final map = {
          'timestamp': '2026-09-29T19:00:00+01:00',
          'zeitQuelle': 'SYSTEM',
        };
        final result = EntityFormatterRegistry.tryFormat(map);
        expect(result, isNotNull);
        expect(result!.icon, Icons.schedule_outlined);
        expect(result.label, contains('2026-09-29 19:00:00 (SYSTEM)'));
      });

      test('formats route / transport leg entity with von... and nach...', () {
        final map = {
          'vonTransportMeilensteinId': '8e435649-a84f',
          'nachTransportMeilensteinId': '12534add-05cb',
        };
        final result = EntityFormatterRegistry.tryFormat(map);
        expect(result, isNotNull);
        expect(result!.icon, Icons.alt_route_outlined);
        expect(result.label, '8e435649-a84f → 12534add-05cb');
      });
    });

    group('Compact primitive list heuristic (tryFormatList)', () {
      test('formats single string list (e.g. aktionsKategorien)', () {
        final list = ['ENTLADESTELLE'];
        final result = EntityFormatterRegistry.tryFormatList(list);
        expect(result, isNotNull);
        expect(result!.icon, Icons.list_alt);
        expect(result.label, '[ "ENTLADESTELLE" ]');
        expect(result.color, Colors.indigoAccent);
      });

      test('formats 2-3 primitive values including numbers and booleans', () {
        final list = ['ACTIVE', 42, true];
        final result = EntityFormatterRegistry.tryFormatList(list);
        expect(result, isNotNull);
        expect(result!.label, '[ "ACTIVE", 42, true ]');
      });

      test('returns null for empty list or list with more than 3 items', () {
        expect(EntityFormatterRegistry.tryFormatList([]), isNull);
        expect(EntityFormatterRegistry.tryFormatList(['A', 'B', 'C', 'D']), isNull);
      });

      test('returns null if items contain complex objects or lists', () {
        expect(EntityFormatterRegistry.tryFormatList([{'key': 'val'}]), isNull);
        expect(EntityFormatterRegistry.tryFormatList([['nested']]), isNull);
      });

      test('returns null if any item is null or empty string', () {
        expect(EntityFormatterRegistry.tryFormatList([null]), isNull);
        expect(EntityFormatterRegistry.tryFormatList(['', 'FOO']), isNull);
        expect(EntityFormatterRegistry.tryFormatList(['   ']), isNull);
      });

      test('returns null if string length or total length exceeds limit', () {
        final longStr = 'a' * 51;
        expect(EntityFormatterRegistry.tryFormatList([longStr]), isNull);

        final str30 = 'a' * 30;
        // 3 * 30 + brackets & quotes > 80 chars
        expect(EntityFormatterRegistry.tryFormatList([str30, str30, str30]), isNull);
      });
    });
  });
}
