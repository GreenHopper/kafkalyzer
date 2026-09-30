import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/explorer_view.dart';
import 'package:kafkalyzer/src/features/consumer/presentation/consumer_lag_view.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/script_manager_view.dart';
import 'package:kafkalyzer/src/features/settings/presentation/settings_view.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/update_dialog.dart';
import 'package:kafkalyzer/src/services/update_service.dart';
import 'package:kafkalyzer/src/theme_controller.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  bool _updateSnackBarShown = false;

  @override
  void initState() {
    super.initState();
    getIt<UpdateService>().availableUpdateNotifier.addListener(
      _onAvailableUpdateChanged,
    );
    // Handle update already discovered before this widget mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onAvailableUpdateChanged();
    });
  }

  @override
  void dispose() {
    getIt<UpdateService>().availableUpdateNotifier.removeListener(
      _onAvailableUpdateChanged,
    );
    super.dispose();
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
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
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
            child: switch (_selectedIndex) {
              0 => const ExplorerView(),
              1 => const ConsumerLagView(),
              2 => const ScriptManagerView(),
              3 => const SettingsView(),
              _ => Center(child: Text(l10n.unknownView)),
            },
          ),
        ],
      ),
    );
  }
}
