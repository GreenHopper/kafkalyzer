import 'package:material_ui/material_ui.dart';

/// Data representation of a recognized composite semantic entity.
class FormattedBadgeData {
  final IconData icon;
  final String label;
  final Color? color;

  const FormattedBadgeData({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormattedBadgeData &&
          runtimeType == other.runtimeType &&
          icon == other.icon &&
          label == other.label &&
          color == other.color;

  @override
  int get hashCode => icon.hashCode ^ label.hashCode ^ color.hashCode;
}

/// Registry and heuristic evaluation engine for progressive disclosure of JSON objects.
class EntityFormatterRegistry {
  /// Evaluates whether a [map] represents a composite entity or compact flat structure.
  /// Returns [FormattedBadgeData] if matched, or `null` if the map should be rendered as a standard tree.
  static FormattedBadgeData? tryFormat(Map<String, dynamic> map) {
    if (map.isEmpty) return null;

    final lowerKeyMap = <String, dynamic>{};
    for (final entry in map.entries) {
      lowerKeyMap[entry.key.toLowerCase()] = entry.value;
    }
    final keys = lowerKeyMap.keys.toSet();

    // 1. Address Heuristic
    if (keys.contains('ort') ||
        keys.contains('city') ||
        keys.contains('plz') ||
        keys.contains('zip')) {
      final street = lowerKeyMap['strasse'] ?? lowerKeyMap['street'] ?? '';
      final zip = lowerKeyMap['plz'] ?? lowerKeyMap['zip'] ?? '';
      final city = lowerKeyMap['ort'] ?? lowerKeyMap['city'] ?? '';
      final cityPart = [zip, city]
          .where((s) => s != null && s.toString().trim().isNotEmpty)
          .join(' ');
      final parts = [street, cityPart]
          .where((s) => s != null && s.toString().trim().isNotEmpty)
          .toList();
      final label = parts.isNotEmpty ? parts.join(', ') : 'Address';

      return FormattedBadgeData(
        icon: Icons.location_on_outlined,
        label: label,
        color: Colors.blueAccent,
      );
    }

    // 2. Date/Time Window / Period Heuristic
    final hasStart = keys.contains('startdate') ||
        keys.contains('validfrom') ||
        keys.contains('from') ||
        keys.contains('valid_from');
    final hasEnd = keys.contains('enddate') ||
        keys.contains('validto') ||
        keys.contains('to') ||
        keys.contains('valid_to');

    if (hasStart && hasEnd) {
      final startVal = lowerKeyMap['startdate'] ??
          lowerKeyMap['validfrom'] ??
          lowerKeyMap['from'] ??
          lowerKeyMap['valid_from'];
      final endVal = lowerKeyMap['enddate'] ??
          lowerKeyMap['validto'] ??
          lowerKeyMap['to'] ??
          lowerKeyMap['valid_to'];

      String formatTimeVal(dynamic v) {
        if (v == null) return '';
        final s = v.toString();
        if (s.contains('T')) {
          return s.split('T').first;
        }
        return s;
      }

      final startStr = formatTimeVal(startVal);
      final endStr = formatTimeVal(endVal);

      if (startStr.isNotEmpty || endStr.isNotEmpty) {
        return FormattedBadgeData(
          icon: Icons.date_range_outlined,
          label: '$startStr → $endStr',
          color: Colors.orangeAccent,
        );
      }
    }

    // 3. Geo-Coordinates Heuristic
    final hasLat = keys.contains('lat') || keys.contains('latitude');
    final hasLon = keys.contains('lon') ||
        keys.contains('lng') ||
        keys.contains('longitude');

    if (hasLat && hasLon) {
      final lat = lowerKeyMap['lat'] ?? lowerKeyMap['latitude'];
      final lon = lowerKeyMap['lon'] ??
          lowerKeyMap['lng'] ??
          lowerKeyMap['longitude'];

      return FormattedBadgeData(
        icon: Icons.pin_drop_outlined,
        label: '$lat, $lon',
        color: Colors.green,
      );
    }

    // 4. Generic Compact Flat Object Heuristic (2 to 4 flat primitive fields)
    if (map.length >= 2 && map.length <= 4) {
      bool isFlatPrimitive = true;
      for (final val in map.values) {
        if (val is Map || val is List) {
          isFlatPrimitive = false;
          break;
        }
        if (val is String && val.length > 50) {
          isFlatPrimitive = false;
          break;
        }
      }

      if (isFlatPrimitive) {
        // Check for primary identifying keys
        final idKey = _findKeyMatching(map, ['id', 'code', 'key']);
        final nameKey = _findKeyMatching(map, ['name', 'title', 'label', 'description', 'value']);

        String label;
        if (idKey != null && nameKey != null && idKey != nameKey) {
          final idVal = map[idKey]?.toString() ?? '';
          final nameVal = map[nameKey]?.toString() ?? '';
          final otherEntries = map.entries
              .where((e) => e.key != idKey && e.key != nameKey)
              .map((e) => '${e.key}: ${e.value}')
              .join(', ');
          if (otherEntries.isEmpty) {
            label = '$idVal • $nameVal';
          } else {
            label = '$idVal • $nameVal ($otherEntries)';
          }
        } else if (map.length == 1) {
          label = '${map.keys.first}: ${map.values.first}';
        } else {
          label = map.entries.map((e) => '${e.key}: ${e.value}').join(', ');
        }

        if (label.length <= 80) {
          return FormattedBadgeData(
            icon: Icons.data_object,
            label: label,
            color: Colors.teal,
          );
        }
      }
    }

    return null;
  }

  static String? _findKeyMatching(Map<String, dynamic> map, List<String> candidates) {
    for (final candidate in candidates) {
      for (final k in map.keys) {
        if (k.toLowerCase() == candidate) {
          return k;
        }
      }
    }
    return null;
  }
}
