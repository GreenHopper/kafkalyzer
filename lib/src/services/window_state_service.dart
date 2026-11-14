import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:logger/logger.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Persisted window geometry loaded from `window_state_v1`.
class SavedWindowState {
  const SavedWindowState({
    required this.width,
    required this.height,
    this.x,
    this.y,
    this.maximized = false,
  });

  final double? x;
  final double? y;
  final double width;
  final double height;
  final bool maximized;

  Map<String, dynamic> toJson() => {
    if (x != null) 'x': x,
    if (y != null) 'y': y,
    'width': width,
    'height': height,
    'maximized': maximized,
  };

  /// Tolerant parser for `window_state_v1`. Returns `null` if invalid or
  /// malformed without modifying persisted storage.
  static SavedWindowState? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final width = _asFiniteDouble(decoded['width']);
      final height = _asFiniteDouble(decoded['height']);
      if (width == null || height == null || width <= 0 || height <= 0) {
        return null;
      }
      final x = _asFiniteDouble(decoded['x']);
      final y = _asFiniteDouble(decoded['y']);
      final maximizedRaw = decoded['maximized'];
      final maximized = maximizedRaw is bool ? maximizedRaw : false;
      return SavedWindowState(
        x: x,
        y: y,
        width: width,
        height: height,
        maximized: maximized,
      );
    } catch (_) {
      return null;
    }
  }

  static double? _asFiniteDouble(Object? value) {
    if (value is num) {
      final d = value.toDouble();
      return d.isFinite ? d : null;
    }
    return null;
  }
}

/// Display bounds used for pure window-restore planning.
class DisplayRect {
  const DisplayRect({required this.visibleFrame, this.isPrimary = false});

  final Rect visibleFrame;
  final bool isPrimary;
}

/// Computed restore plan for the application window.
class WindowRestorePlan {
  const WindowRestorePlan({
    required this.size,
    this.position,
    this.maximize = false,
  });

  final Size size;
  final Offset? position;
  final bool maximize;
}

/// Pure function computing window size, position, and maximize state on startup.
WindowRestorePlan planRestore(
  SavedWindowState? saved,
  List<DisplayRect> displays, {
  required bool isWayland,
  Size defaultSize = const Size(1280, 720),
  Size minSize = const Size(640, 480),
}) {
  final rawSize = saved != null ? Size(saved.width, saved.height) : defaultSize;

  if (displays.isEmpty) {
    final clampedSize = Size(
      math.max(minSize.width, rawSize.width),
      math.max(minSize.height, rawSize.height),
    );
    final pos = (!isWayland && saved?.x != null && saved?.y != null)
        ? Offset(saved!.x!, saved.y!)
        : null;
    return WindowRestorePlan(
      size: clampedSize,
      position: pos,
      maximize: saved?.maximized ?? false,
    );
  }

  final primary = displays.firstWhere(
    (d) => d.isPrimary,
    orElse: () => displays.first,
  );

  DisplayRect? visibleDisplay;
  Offset? restoredPosition;

  if (!isWayland && saved != null && saved.x != null && saved.y != null) {
    final candidateSize = Size(
      math.max(minSize.width, rawSize.width),
      math.max(minSize.height, rawSize.height),
    );
    final candidateRect = Rect.fromLTWH(
      saved.x!,
      saved.y!,
      candidateSize.width,
      candidateSize.height,
    );
    for (final display in displays) {
      final overlapW =
          math.min(candidateRect.right, display.visibleFrame.right) -
          math.max(candidateRect.left, display.visibleFrame.left);
      final overlapH =
          math.min(candidateRect.bottom, display.visibleFrame.bottom) -
          math.max(candidateRect.top, display.visibleFrame.top);
      if (overlapW >= 100 && overlapH >= 50) {
        visibleDisplay = display;
        restoredPosition = Offset(saved.x!, saved.y!);
        break;
      }
    }
  }

  final targetDisplay = visibleDisplay ?? primary;
  final maxW = math.max(minSize.width, targetDisplay.visibleFrame.width);
  final maxH = math.max(minSize.height, targetDisplay.visibleFrame.height);
  final clampedSize = Size(
    rawSize.width.clamp(minSize.width, maxW).toDouble(),
    rawSize.height.clamp(minSize.height, maxH).toDouble(),
  );

  return WindowRestorePlan(
    size: clampedSize,
    position: isWayland ? null : restoredPosition,
    maximize: saved?.maximized ?? false,
  );
}

/// Abstraction over `window_manager` and `screen_retriever` for testability.
abstract class WindowAdapter {
  Future<void> ensureInitialized();
  Future<void> waitUntilReadyToShow(
    WindowOptions options,
    Future<void> Function() callback,
  );
  Future<void> setPosition(Offset position);
  Future<void> maximize();
  Future<void> show();
  Future<void> focus();
  Future<bool> isMaximized();
  Future<Rect> getBounds();
  Future<List<DisplayRect>> getDisplays();
  void addListener(WindowListener listener);
  void removeListener(WindowListener listener);
}

class DefaultWindowAdapter implements WindowAdapter {
  @override
  Future<void> ensureInitialized() => windowManager.ensureInitialized();

  @override
  Future<void> waitUntilReadyToShow(
    WindowOptions options,
    Future<void> Function() callback,
  ) => windowManager.waitUntilReadyToShow(options, callback);

  @override
  Future<void> setPosition(Offset position) =>
      windowManager.setPosition(position);

  @override
  Future<void> maximize() => windowManager.maximize();

  @override
  Future<void> show() => windowManager.show();

  @override
  Future<void> focus() => windowManager.focus();

  @override
  Future<bool> isMaximized() => windowManager.isMaximized();

  @override
  Future<Rect> getBounds() => windowManager.getBounds();

  @override
  Future<List<DisplayRect>> getDisplays() async {
    final primary = await screenRetriever.getPrimaryDisplay();
    final all = await screenRetriever.getAllDisplays();
    return all.map((d) {
      final pos = d.visiblePosition ?? Offset.zero;
      final size = d.visibleSize ?? d.size;
      return DisplayRect(
        visibleFrame: Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height),
        isPrimary: d.id == primary.id,
      );
    }).toList();
  }

  @override
  void addListener(WindowListener listener) =>
      windowManager.addListener(listener);

  @override
  void removeListener(WindowListener listener) =>
      windowManager.removeListener(listener);
}

/// Restores and persists window size, position, and maximized state.
class WindowStateService with WindowListener {
  WindowStateService({
    WindowAdapter? adapter,
    Logger? logger,
    bool Function()? isWaylandDetector,
    this.saveDebounceDelay = const Duration(milliseconds: 500),
  }) : _adapter = adapter ?? DefaultWindowAdapter(),
       _logger = logger ?? Logger(),
       _isWaylandDetector = isWaylandDetector ?? _defaultIsWayland;

  static const String storageKey = 'window_state_v1';
  static const Size defaultSize = Size(1280, 720);
  static const Size minSize = Size(640, 480);

  final WindowAdapter _adapter;
  final Logger _logger;
  final bool Function() _isWaylandDetector;
  final Duration saveDebounceDelay;

  Timer? _saveTimer;
  Rect? _lastNormalBounds;
  bool _listenerAttached = false;

  static bool _defaultIsWayland() {
    if (!Platform.isLinux) return false;
    final waylandDisplay = Platform.environment['WAYLAND_DISPLAY'];
    final sessionType = Platform.environment['XDG_SESSION_TYPE'];
    return (waylandDisplay != null && waylandDisplay.isNotEmpty) ||
        sessionType == 'wayland';
  }

  /// Restores saved window bounds and shows the window even if restore fails.
  Future<void> restore() async {
    var readyCalled = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = SavedWindowState.tryParse(prefs.getString(storageKey));
      if (saved != null && saved.x != null && saved.y != null) {
        _lastNormalBounds = Rect.fromLTWH(
          saved.x!,
          saved.y!,
          saved.width,
          saved.height,
        );
      } else if (saved != null) {
        _lastNormalBounds = Rect.fromLTWH(0, 0, saved.width, saved.height);
      }

      await _adapter.ensureInitialized();
      List<DisplayRect> displays = const [];
      try {
        displays = await _adapter.getDisplays();
      } catch (e, st) {
        _logger.w(
          'Failed to query displays; using defaults',
          error: e,
          stackTrace: st,
        );
      }

      final plan = planRestore(
        saved,
        displays,
        isWayland: _isWaylandDetector(),
        defaultSize: defaultSize,
        minSize: minSize,
      );

      final options = WindowOptions(
        size: plan.size,
        minimumSize: minSize,
        center: plan.position == null,
      );

      await _adapter.waitUntilReadyToShow(options, () async {
        readyCalled = true;
        if (plan.position != null) {
          await _adapter.setPosition(plan.position!);
        }
        if (plan.maximize) {
          await _adapter.maximize();
        }
      });
    } catch (e, st) {
      _logger.w(
        'Window state restore failed; showing default window',
        error: e,
        stackTrace: st,
      );
    } finally {
      if (!readyCalled) {
        try {
          await _adapter.ensureInitialized();
        } catch (_) {}
      }
      try {
        await _adapter.show();
        await _adapter.focus();
      } catch (e, st) {
        _logger.w('Failed to show/focus window', error: e, stackTrace: st);
      }
    }
  }

  void attachListener() {
    if (_listenerAttached) return;
    _adapter.addListener(this);
    _listenerAttached = true;
  }

  void detachListener() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_listenerAttached) {
      _adapter.removeListener(this);
      _listenerAttached = false;
    }
  }

  @override
  void onWindowResize() => _scheduleSave();

  @override
  void onWindowMove() => _scheduleSave();

  @override
  void onWindowMaximize() => _scheduleSave();

  @override
  void onWindowUnmaximize() => _scheduleSave();

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDebounceDelay, saveNow);
  }

  Future<void> saveNow() async {
    try {
      final isMaximized = await _adapter.isMaximized();
      final prefs = await SharedPreferences.getInstance();
      final existing = SavedWindowState.tryParse(prefs.getString(storageKey));

      late final SavedWindowState next;
      if (isMaximized) {
        final normal = _lastNormalBounds;
        if (normal != null) {
          next = SavedWindowState(
            x: normal.left,
            y: normal.top,
            width: normal.width,
            height: normal.height,
            maximized: true,
          );
        } else if (existing != null) {
          next = SavedWindowState(
            x: existing.x,
            y: existing.y,
            width: existing.width,
            height: existing.height,
            maximized: true,
          );
        } else {
          next = SavedWindowState(
            width: defaultSize.width,
            height: defaultSize.height,
            maximized: true,
          );
        }
      } else {
        final bounds = await _adapter.getBounds();
        _lastNormalBounds = bounds;
        next = SavedWindowState(
          x: _isWaylandDetector() ? existing?.x : bounds.left,
          y: _isWaylandDetector() ? existing?.y : bounds.top,
          width: bounds.width,
          height: bounds.height,
          maximized: false,
        );
      }

      await prefs.setString(storageKey, jsonEncode(next.toJson()));
    } catch (e, st) {
      _logger.w('Failed to save window state', error: e, stackTrace: st);
    }
  }
}
