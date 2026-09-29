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
        keys.contains('valid_from') ||
        keys.contains('plantimestampvon') ||
        keys.contains('von');
    final hasEnd = keys.contains('enddate') ||
        keys.contains('validto') ||
        keys.contains('to') ||
        keys.contains('valid_to') ||
        keys.contains('plantimestampbis') ||
        keys.contains('bis');

    if (hasStart && hasEnd) {
      final startVal = lowerKeyMap['startdate'] ??
          lowerKeyMap['validfrom'] ??
          lowerKeyMap['from'] ??
          lowerKeyMap['valid_from'] ??
          lowerKeyMap['plantimestampvon'] ??
          lowerKeyMap['von'];
      final endVal = lowerKeyMap['enddate'] ??
          lowerKeyMap['validto'] ??
          lowerKeyMap['to'] ??
          lowerKeyMap['valid_to'] ??
          lowerKeyMap['plantimestampbis'] ??
          lowerKeyMap['bis'];

      String formatTimeVal(dynamic v) {
        if (v == null) return '';
        if (v is Map) {
          // Extract nested timestamp if present
          final inner = v['timestamp'] ?? v['zeit'] ?? v['val'] ?? v.values.firstOrNull;
          return formatTimeVal(inner);
        }
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

    // 3. Standalone Timestamp with Metadata Heuristic (e.g. { timestamp: '...', zeitQuelle: '...' })
    final timestampKey = _findKeyMatching(map, ['timestamp', 'zeit', 'datetime', 'zeitstempel']);
    if (timestampKey != null && map.length >= 2) {
      final tsVal = map[timestampKey];
      if (tsVal is String || tsVal is num) {
        final metaKey = _findKeyMatching(map, ['zeitquelle', 'source', 'quelle', 'origin', 'type']);
        final metaVal = metaKey != null ? map[metaKey]?.toString() : null;
        String tsDisplay = tsVal.toString();
        if (tsDisplay.contains('T')) {
          final parts = tsDisplay.split('T');
          final timePart = parts.length > 1 ? parts[1].split('+').first.split('Z').first : '';
          tsDisplay = timePart.isNotEmpty ? '${parts[0]} $timePart' : parts[0];
        }
        final label = (metaVal != null && metaVal.isNotEmpty)
            ? '$tsDisplay ($metaVal)'
            : tsDisplay;
        return FormattedBadgeData(
          icon: Icons.schedule_outlined,
          label: label,
          color: Colors.amber.shade800,
        );
      }
    }

    // 4. Route / Transport Leg Heuristic (von/nach, from/to, origin/destination)
    String? originKey;
    String? destKey;
    for (final k in map.keys) {
      final lk = k.toLowerCase();
      if (lk.startsWith('von') || lk == 'from' || lk == 'origin' || lk == 'source') {
        originKey = k;
      } else if (lk.startsWith('nach') || lk == 'to' || lk == 'destination' || lk == 'target') {
        destKey = k;
      }
    }
    if (originKey != null && destKey != null && originKey != destKey) {
      final originVal = map[originKey]?.toString() ?? '';
      final destVal = map[destKey]?.toString() ?? '';
      if (originVal.isNotEmpty || destVal.isNotEmpty) {
        return FormattedBadgeData(
          icon: Icons.alt_route_outlined,
          label: '$originVal → $destVal',
          color: Colors.indigoAccent,
        );
      }
    }

    // 5. Geo-Coordinates Heuristic
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

    // 6. Generic Compact Flat Object Heuristic (Evaluating Non-Null, Non-Empty Properties)
    final nonNullEntries = map.entries.where((e) {
      final v = e.value;
      if (v == null) return false;
      if (v is List && v.isEmpty) return false;
      if (v is Map && v.isEmpty) return false;
      return true;
    }).toList();

    if (nonNullEntries.length >= 2 && nonNullEntries.length <= 4) {
      bool isFlatPrimitive = true;
      for (final entry in nonNullEntries) {
        final val = entry.value;
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
        final activeMap = Map.fromEntries(nonNullEntries);
        // Check for primary identifying keys
        final idKey = _findKeyMatching(activeMap, ['id', 'art', 'type', 'code', 'key']);
        final nameKey = _findKeyMatching(activeMap, ['name', 'title', 'label', 'description', 'value', 'status']);

        String label;
        if (idKey != null && nameKey != null && idKey != nameKey) {
          final idVal = activeMap[idKey]?.toString() ?? '';
          final nameVal = activeMap[nameKey]?.toString() ?? '';
          final otherEntries = activeMap.entries
              .where((e) => e.key != idKey && e.key != nameKey)
              .map((e) => '${e.key}: ${e.value}')
              .join(', ');
          if (otherEntries.isEmpty) {
            label = '$idVal • $nameVal';
          } else {
            label = '$idVal • $nameVal ($otherEntries)';
          }
        } else if (activeMap.length == 1) {
          label = '${activeMap.keys.first}: ${activeMap.values.first}';
        } else {
          label = activeMap.entries.map((e) => '${e.key}: ${e.value}').join(', ');
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

  /// Evaluates whether a [list] represents a compact list of simple values (1 to 3 primitives).
  ///
  /// Returns [FormattedBadgeData] if matched, or `null` if the list should be rendered as a standard tree.
  static FormattedBadgeData? tryFormatList(List<dynamic> list) {
    if (list.isEmpty || list.length > 3) return null;

    final formattedItems = <String>[];
    for (final item in list) {
      if (item == null) return null;
      if (item is Map || item is List) return null;
      if (item is String) {
        if (item.trim().isEmpty || item.length > 50) return null;
        formattedItems.add('"$item"');
      } else if (item is num || item is bool) {
        formattedItems.add(item.toString());
      } else {
        return null;
      }
    }

    final label = '[ ${formattedItems.join(', ')} ]';
    if (label.length > 80) return null;

    return FormattedBadgeData(
      icon: Icons.list_alt,
      label: label,
      color: Colors.indigoAccent,
    );
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
