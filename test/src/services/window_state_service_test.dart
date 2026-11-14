import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/main.dart' as app_main;
import 'package:kafkalyzer/src/services/window_state_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

class _FakeWindowAdapter implements WindowAdapter {
  bool initialized = false;
  bool shown = false;
  bool focused = false;
  bool maximized = false;
  bool throwOnWaitUntilReady = false;
  Rect bounds = const Rect.fromLTWH(100, 120, 1024, 700);
  List<DisplayRect> displays = const [
    DisplayRect(visibleFrame: Rect.fromLTWH(0, 0, 1920, 1080), isPrimary: true),
  ];
  final List<WindowListener> listeners = [];
  WindowOptions? lastOptions;
  Offset? lastSetPosition;
  bool maximizeCalled = false;

  @override
  Future<void> ensureInitialized() async {
    initialized = true;
  }

  @override
  Future<void> waitUntilReadyToShow(
    WindowOptions options,
    Future<void> Function() callback,
  ) async {
    lastOptions = options;
    if (throwOnWaitUntilReady) {
      throw StateError('boom');
    }
    await callback();
  }

  @override
  Future<void> setPosition(Offset position) async {
    lastSetPosition = position;
  }

  @override
  Future<void> maximize() async {
    maximizeCalled = true;
    maximized = true;
  }

  @override
  Future<void> show() async {
    shown = true;
  }

  @override
  Future<void> focus() async {
    focused = true;
  }

  @override
  Future<bool> isMaximized() async => maximized;

  @override
  Future<Rect> getBounds() async => bounds;

  @override
  Future<List<DisplayRect>> getDisplays() async => displays;

  @override
  void addListener(WindowListener listener) {
    listeners.add(listener);
  }

  @override
  void removeListener(WindowListener listener) {
    listeners.remove(listener);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const primary1080p = [
    DisplayRect(visibleFrame: Rect.fromLTWH(0, 0, 1920, 1080), isPrimary: true),
  ];

  group('SavedWindowState.tryParse', () {
    test('returns null on null, empty, corrupt, or invalid bounds', () {
      expect(SavedWindowState.tryParse(null), isNull);
      expect(SavedWindowState.tryParse(''), isNull);
      expect(SavedWindowState.tryParse('{bad json'), isNull);
      expect(SavedWindowState.tryParse('[1, 2, 3]'), isNull);
      expect(SavedWindowState.tryParse('{"width": 0, "height": 500}'), isNull);
      expect(SavedWindowState.tryParse('{"width": 800}'), isNull);
    });

    test('parses valid JSON tolerantly', () {
      final parsed = SavedWindowState.tryParse(
        '{"x": 10, "y": 20, "width": 1000, "height": 700, "maximized": "yes"}',
      );
      expect(parsed, isNotNull);
      expect(parsed!.x, 10);
      expect(parsed.y, 20);
      expect(parsed.width, 1000);
      expect(parsed.height, 700);
      expect(parsed.maximized, isFalse);
    });
  });

  group('planRestore', () {
    test('missing state uses default 1280x720 centred', () {
      final plan = planRestore(null, primary1080p, isWayland: false);
      expect(plan.size, const Size(1280, 720));
      expect(plan.position, isNull);
      expect(plan.maximize, isFalse);
    });

    test('off-screen saved position falls back to centred', () {
      const saved = SavedWindowState(
        x: 1850, // only 70px overlap (< 100px strip)
        y: 100,
        width: 900,
        height: 600,
      );
      final plan = planRestore(saved, primary1080p, isWayland: false);
      expect(plan.size, const Size(900, 600));
      expect(plan.position, isNull);
    });

    test('100x50 visible strip preserves position', () {
      const saved = SavedWindowState(
        x: 1820, // 100px overlap
        y: 1030, // 50px overlap
        width: 900,
        height: 600,
      );
      final plan = planRestore(saved, primary1080p, isWayland: false);
      expect(plan.position, const Offset(1820, 1030));
    });

    test('clamps too-large size to display visible frame', () {
      const saved = SavedWindowState(x: 0, y: 0, width: 3000, height: 2000);
      final plan = planRestore(saved, primary1080p, isWayland: false);
      expect(plan.size, const Size(1920, 1080));
      expect(plan.position, Offset.zero);
    });

    test('clamps too-small size to minimum 640x480', () {
      const saved = SavedWindowState(x: 50, y: 50, width: 200, height: 150);
      final plan = planRestore(saved, primary1080p, isWayland: false);
      expect(plan.size, const Size(640, 480));
    });

    test('preserves maximize flag', () {
      const saved = SavedWindowState(
        x: 100,
        y: 100,
        width: 1000,
        height: 700,
        maximized: true,
      );
      final plan = planRestore(saved, primary1080p, isWayland: false);
      expect(plan.maximize, isTrue);
      expect(plan.position, const Offset(100, 100));
    });

    test('Wayland restores size and maximize only, never position', () {
      const saved = SavedWindowState(
        x: 150,
        y: 250,
        width: 1100,
        height: 750,
        maximized: true,
      );
      final plan = planRestore(saved, primary1080p, isWayland: true);
      expect(plan.size, const Size(1100, 750));
      expect(plan.position, isNull);
      expect(plan.maximize, isTrue);
    });
  });

  group('WindowStateService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'restore shows and focuses window even when waitUntilReadyToShow throws',
      () async {
        final adapter = _FakeWindowAdapter()..throwOnWaitUntilReady = true;
        final service = WindowStateService(
          adapter: adapter,
          isWaylandDetector: () => false,
        );

        await service.restore();

        expect(adapter.initialized, isTrue);
        expect(adapter.shown, isTrue);
        expect(adapter.focused, isTrue);
      },
    );

    test('debounces save and preserves normal bounds when maximized', () async {
      final adapter = _FakeWindowAdapter();
      final service = WindowStateService(
        adapter: adapter,
        isWaylandDetector: () => false,
        saveDebounceDelay: const Duration(milliseconds: 30),
      );
      service.attachListener();

      // Normal resize -> debounced save
      adapter.bounds = const Rect.fromLTWH(40, 60, 1100, 720);
      service.onWindowResize();
      service.onWindowMove();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final prefs = await SharedPreferences.getInstance();
      final saved1 = SavedWindowState.tryParse(
        prefs.getString(WindowStateService.storageKey),
      );
      expect(saved1?.width, 1100);
      expect(saved1?.height, 720);
      expect(saved1?.x, 40);
      expect(saved1?.y, 60);
      expect(saved1?.maximized, isFalse);

      // Maximize -> keeps normal bounds 1100x720 while setting maximized: true
      adapter.maximized = true;
      adapter.bounds = const Rect.fromLTWH(0, 0, 1920, 1080);
      service.onWindowMaximize();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final saved2 = SavedWindowState.tryParse(
        prefs.getString(WindowStateService.storageKey),
      );
      expect(saved2?.maximized, isTrue);
      expect(saved2?.width, 1100);
      expect(saved2?.height, 720);
      expect(saved2?.x, 40);
      expect(saved2?.y, 60);

      service.detachListener();
    });

    test('headless invocation never writes window_state_v1', () async {
      SharedPreferences.setMockInitialValues({
        WindowStateService.storageKey: jsonEncode({
          'x': 10,
          'y': 20,
          'width': 900,
          'height': 600,
          'maximized': false,
        }),
      });
      expect(app_main.isHeadlessInvocation(['--help']), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(
        SavedWindowState.tryParse(
          prefs.getString(WindowStateService.storageKey),
        )?.width,
        900,
      );
    });
  });
}
