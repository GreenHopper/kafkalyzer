import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'package:kafkalyzer/src/dependency_injection.dart';

/// Service responsible for launching exported files in default system applications
/// or revealing their containing directory in the host desktop file manager.
class FileOpenerService {
  final Logger _logger;

  FileOpenerService({Logger? logger}) : _logger = logger ?? getIt<Logger>();

  /// Opens the file at [filePath] using the system's registered default application.
  Future<bool> openFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _logger.w('Cannot open file: path does not exist ($filePath)');
        return false;
      }

      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(uri);
        if (launched) {
          _logger.i('Successfully opened file via url_launcher: $filePath');
          return true;
        }
      }

      // Fallback to operating system commands
      if (Platform.isMacOS) {
        final result = await Process.run('open', [filePath]);
        return result.exitCode == 0;
      } else if (Platform.isWindows) {
        final result = await Process.run('cmd.exe', [
          '/c',
          'start',
          '',
          filePath,
        ]);
        return result.exitCode == 0;
      } else if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [filePath]);
        return result.exitCode == 0;
      }

      return false;
    } catch (e, st) {
      _logger.e('Failed to open file: $filePath', error: e, stackTrace: st);
      return false;
    }
  }

  /// Reveals or opens the containing directory of [filePath] in the desktop file manager.
  /// Where supported (macOS Finder, Windows Explorer), highlights the file.
  Future<bool> showInFolder(String filePath) async {
    try {
      final file = File(filePath);
      final parentDir = file.parent;

      if (!await parentDir.exists()) {
        _logger.w(
          'Cannot show in folder: parent directory does not exist for $filePath',
        );
        return false;
      }

      if (Platform.isMacOS) {
        // macOS Finder reveals and selects the item
        final result = await Process.run('open', ['-R', filePath]);
        if (result.exitCode == 0) return true;
        // Fallback to opening folder directly
        final dirResult = await Process.run('open', [parentDir.path]);
        return dirResult.exitCode == 0;
      } else if (Platform.isWindows) {
        // Windows Explorer selects the file if it exists, otherwise opens the folder
        final normalizedPath = p.normalize(filePath);
        final result = await Process.run('explorer.exe', [
          '/select,',
          normalizedPath,
        ]);
        if (result.exitCode == 0 || result.exitCode == 1) return true;

        final dirResult = await Process.run('explorer.exe', [
          p.normalize(parentDir.path),
        ]);
        return dirResult.exitCode == 0 || dirResult.exitCode == 1;
      } else if (Platform.isLinux) {
        // Linux desktop environments
        final result = await Process.run('xdg-open', [parentDir.path]);
        return result.exitCode == 0;
      } else {
        final uri = Uri.file(parentDir.path);
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri);
        }
      }

      return false;
    } catch (e, st) {
      _logger.e(
        'Failed to show file in folder: $filePath',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }
}
