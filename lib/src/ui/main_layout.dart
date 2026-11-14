import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/tls_transition_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/tls_transition_dialog.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/explorer_view.dart';
import 'package:kafkalyzer/src/features/consumer/presentation/consumer_lag_view.dart';
import 'package:kafkalyzer/src/features/navigation/command_palette/command_palette_dialog.dart';
import 'package:kafkalyzer/src/features/navigation/main_navigation_controller.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/script_manager_view.dart';
import 'package:kafkalyzer/src/features/settings/presentation/settings_view.dart';
import 'package:kafkalyzer/src/ui/focus_utils.dart';
import 'package:kafkalyzer/src/ui/shortcuts/app_shortcuts.dart';
import 'package:kafkalyzer/src/ui/shortcuts/shortcut_overview_dialog.dart';
import 'package:kafkalyzer/src/ui/storage_notice_banner.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/update_dialog.dart';
import 'package:kafkalyzer/src/services/diagnostics/error_reporter.dart';
import 'package:kafkalyzer/src/services/update_service.dart';
import 'package:kafkalyzer/src/theme_controller.dart';
import 'package:kafkalyzer/src/ui/error_details_dialog.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late final MainNavigationController _navController;
  bool _ownsNavController = false;
  bool _updateSnackBarShown = false;
  bool _showingTlsDialog = false;
  bool _showingShortcutOverview = false;
  bool _showingCommandPalette = false;

  @override
  void initState() {
    super.initState();
    if (getIt.isRegistered<MainNavigationController>()) {
      _navController = getIt<MainNavigationController>();
    } else {
      _navController = MainNavigationController();
      _ownsNavController = true;
    }
    _navController.addListener(_onNavigationChanged);
    HardwareKeyboard.instance.addHandler(_handleGlobalShortcut);
    getIt<UpdateService>().availableUpdateNotifier.addListener(
      _onAvailableUpdateChanged,
    );
    if (getIt.isRegistered<TlsTransitionController>()) {
      getIt<TlsTransitionController>().addListener(_onTlsDecisionsChanged);
    }
    if (getIt.isRegistered<ErrorReporter>()) {
      getIt<ErrorReporter>().pendingNotice.addListener(_onErrorNoticeChanged);
    }
    // Handle update or error already discovered before this widget mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onAvailableUpdateChanged();
      _onTlsDecisionsChanged();
      _onErrorNoticeChanged();
    });
  }

  @override
  void dispose() {
    _navController.removeListener(_onNavigationChanged);
    if (_ownsNavController) {
      _navController.dispose();
    }
    HardwareKeyboard.instance.removeHandler(_handleGlobalShortcut);
    getIt<UpdateService>().availableUpdateNotifier.removeListener(
      _onAvailableUpdateChanged,
    );
    if (getIt.isRegistered<TlsTransitionController>()) {
      getIt<TlsTransitionController>().removeListener(_onTlsDecisionsChanged);
    }
    if (getIt.isRegistered<ErrorReporter>()) {
      getIt<ErrorReporter>().pendingNotice.removeListener(
        _onErrorNoticeChanged,
      );
    }
    super.dispose();
  }

  void _onNavigationChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _handleGlobalShortcut(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!mounted) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;

    final matchesPalette = AppShortcuts.commandPalette.activators.any(
      (a) => a.accepts(event, HardwareKeyboard.instance),
    );
    if (matchesPalette) {
      if (_showingCommandPalette) return true;
      final isMacCtrlK =
          defaultTargetPlatform == TargetPlatform.macOS &&
          HardwareKeyboard.instance.isControlPressed &&
          !HardwareKeyboard.instance.isMetaPressed;
      if (isMacCtrlK && isTextInputFocused()) {
        return false;
      }
      _openCommandPalette();
      return true;
    }

    if (_showingShortcutOverview) return false;
    final isF1 = event.logicalKey == LogicalKeyboardKey.f1;
    final isQuestion = event.character == '?';
    if (!isF1 && (!isQuestion || isTextInputFocused())) {
      return false;
    }

    _openShortcutOverview();
    return true;
  }

  Future<void> _openCommandPalette() async {
    if (_showingCommandPalette) return;
    _showingCommandPalette = true;
    try {
      await CommandPaletteDialog.show(context);
    } finally {
      _showingCommandPalette = false;
    }
  }

  Future<void> _openShortcutOverview() async {
    if (_showingShortcutOverview) return;
    _showingShortcutOverview = true;
    try {
      await ShortcutOverviewDialog.show(context);
    } finally {
      _showingShortcutOverview = false;
    }
  }

  void _onErrorNoticeChanged() {
    if (!mounted || !getIt.isRegistered<ErrorReporter>()) return;
    final reporter = getIt<ErrorReporter>();
    final record = reporter.pendingNotice.value;
    if (record == null) return;

    reporter.clearPendingNotice();
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(l10n.errorUnexpectedNotice),
        action: SnackBarAction(
          label: l10n.errorDetailsAction,
          onPressed: () => ErrorDetailsDialog.show(context, record),
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  Future<void> _onTlsDecisionsChanged() async {
    if (!mounted ||
        _showingTlsDialog ||
        !getIt.isRegistered<TlsTransitionController>()) {
      return;
    }
    final controller = getIt<TlsTransitionController>();
    final decision = controller.currentDecision;
    if (decision == null) return;

    _showingTlsDialog = true;
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => TlsTransitionDialog(decision: decision),
      );
      if (result == null) {
        controller.dismissDecision(decision);
      } else {
        await controller.resolveDecision(
          decision,
          keepVerificationEnabled: result,
        );
      }
    } finally {
      _showingTlsDialog = false;
      if (mounted && controller.currentDecision != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onTlsDecisionsChanged();
        });
      }
    }
  }

  void _onAvailableUpdateChanged() {
    if (!mounted || _updateSnackBarShown) {
      return;
    }

    final updateInfo = getIt<UpdateService>().availableUpdateNotifier.value;
    if (updateInfo == null) {
      return;
    }

    _updateSnackBarShown = true;
    final l10n = AppLocalizations.of(context)!;
    final version = updateInfo.targetFullRelease.version;
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(l10n.backgroundUpdateAvailable(version)),
        action: SnackBarAction(
          label: l10n.updateAction,
          onPressed: () => UpdateDialog.show(context),
        ),
        duration: const Duration(seconds: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: Theme.of(context).colorScheme.surface,
            selectedIndex: _navController.railIndex,
            onDestinationSelected: _navController.selectIndex,
            labelType: NavigationRailLabelType.all,
            groupAlignment: -1.0, // Top align
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.explore_outlined),
                selectedIcon: const Icon(Icons.explore),
                label: Text(l10n.explorer),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.speed_outlined),
                selectedIcon: const Icon(Icons.speed),
                label: Text(l10n.consumerLag),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.description_outlined),
                selectedIcon: const Icon(Icons.description),
                label: Text(l10n.scripts),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: Text(l10n.settings),
              ),
            ],
            trailing: Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedBuilder(
                      animation: getIt<ThemeController>(),
                      builder: (context, _) {
                        final isDark = getIt<ThemeController>().isDarkMode;
                        return IconButton(
                          icon: Icon(
                            isDark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                          ),
                          tooltip: isDark
                              ? l10n.switchLightMode
                              : l10n.switchDarkMode,
                          onPressed: () =>
                              getIt<ThemeController>().toggleTheme(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          VerticalDivider(
            thickness: 1,
            width: 1,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          Expanded(
            child: Column(
              children: [
                const StorageNoticeBanner(),
                Expanded(
                  child: switch (_navController.destination) {
                    MainDestination.explorer => const ExplorerView(),
                    MainDestination.consumerLag => const ConsumerLagView(),
                    MainDestination.scripts => const ScriptManagerView(),
                    MainDestination.settings => const SettingsView(),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
