import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Thrown when an archive contains an entry or derived path segment that
/// could escape the target extraction directory.
class UnsafeArchiveEntryException implements Exception {
  final String entryName;

  const UnsafeArchiveEntryException(this.entryName);

  @override
  String toString() => 'Unsafe archive entry: $entryName';
}

final RegExp _driveLetterPrefix = RegExp(r'^[A-Za-z]:');
final RegExp _windowsReservedDevice = RegExp(
  r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$',
  caseSensitive: false,
);

/// Validates [entryName] as a relative path within [rootDir] using both `/`
/// and `\` as separators regardless of the host platform.
///
/// Returns the normalised target path inside [rootDir], or `null` if the entry
/// is empty, contains NUL bytes, is absolute (leading `/`, `\`, drive letter,
/// or UNC), contains any `..` segment, or otherwise resolves outside [rootDir].
String? safeArchiveTarget(String rootDir, String entryName) {
  if (entryName.isEmpty || entryName.contains('\x00')) {
    return null;
  }
  if (entryName.startsWith('/') || entryName.startsWith('\\')) {
    return null;
  }
  if (_driveLetterPrefix.hasMatch(entryName)) {
    return null;
  }

  final rawSegments = entryName.split(RegExp(r'[/\\]'));
  final segments = <String>[];
  for (final seg in rawSegments) {
    if (seg == '..') {
      return null;
    }
    if (seg.isEmpty || seg == '.') {
      continue;
    }
    segments.add(seg);
  }

  if (segments.isEmpty) {
    return null;
  }

  final normalizedRoot = p.normalize(rootDir);
  final target = p.normalize(p.joinAll([normalizedRoot, ...segments]));
  if (!p.isWithin(normalizedRoot, target)) {
    return null;
  }
  return target;
}

/// Returns `true` if [segment] is a safe single path segment (e.g. a run id).
bool isSafePathSegment(String segment) {
  if (segment.isEmpty || segment == '.' || segment == '..') {
    return false;
  }
  if (segment.contains('/') ||
      segment.contains('\\') ||
      segment.contains('\x00')) {
    return false;
  }
  if (_driveLetterPrefix.hasMatch(segment)) {
    return false;
  }
  if (RegExp(r'[\x00-\x1f]').hasMatch(segment)) {
    return false;
  }
  return true;
}

/// Sanitises [name] into a single safe directory/file name segment.
///
/// Replaces `<>:"/\|?*`, control characters, and whitespace with `_`, trims
/// trailing dots and spaces, maps empty / `.` / `..` to `_`, and prefixes
/// Windows reserved device names with `_`.
String safePathSegment(String name) {
  var sanitized = name.replaceAll(RegExp(r'[. ]+$'), '');
  sanitized = sanitized.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f\s]'), '_');
  sanitized = sanitized.replaceAll(RegExp(r'[. ]+$'), '');
  if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') {
    return '_';
  }
  if (_windowsReservedDevice.hasMatch(sanitized)) {
    return '_$sanitized';
  }
  return sanitized;
}

/// Validates every entry in [archive] (including directory entries, symlinks,
/// and unselected entries) before returning a write plan mapping each selected
/// file entry to its normalised target path under [rootDir].
///
/// Throws [UnsafeArchiveEntryException] on the first unsafe entry.
Map<ArchiveFile, String> planArchiveExtraction(
  Archive archive,
  String rootDir, {
  bool Function(String entryName)? select,
  String Function(String entryName)? mapEntryName,
}) {
  final plan = <ArchiveFile, String>{};
  for (final entry in archive) {
    if (entry.isSymbolicLink) {
      throw UnsafeArchiveEntryException(entry.name);
    }

    // Directory entries in zips often end with '/', e.g. 'step1/'.
    // Reject '.' or '..' or root-escaping directory entries too.
    final rawTarget = safeArchiveTarget(rootDir, entry.name);
    if (rawTarget == null) {
      throw UnsafeArchiveEntryException(entry.name);
    }

    if (!entry.isFile) {
      continue;
    }

    if (select != null && !select(entry.name)) {
      continue;
    }

    if (mapEntryName != null) {
      final mappedName = mapEntryName(entry.name);
      final mappedTarget = safeArchiveTarget(rootDir, mappedName);
      if (mappedTarget == null) {
        throw UnsafeArchiveEntryException(entry.name);
      }
      plan[entry] = mappedTarget;
    } else {
      plan[entry] = rawTarget;
    }
  }
  return plan;
}
