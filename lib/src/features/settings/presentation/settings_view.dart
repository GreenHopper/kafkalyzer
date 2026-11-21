import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:watch_it/watch_it.dart';

import 'package:kafkalyzer/src/features/settings/presentation/controllers/settings_import_export_controller.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/general_settings_section.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/settings_cluster_section.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/settings_config_section.dart';

import 'package:kafkalyzer/src/features/settings/presentation/widgets/settings_appearance_section.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/settings_diagnostics_section.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/settings_about_and_updates_section.dart';

class SettingsView extends WatchingStatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Created on first use so the settings screen does not need the export
  // services registered until an export is actually started.
  late final SettingsImportExportController _exportController =
      SettingsImportExportController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              Text(
                l10n.settings,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              SettingsAppearanceSection(l10n: l10n),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 32),
              const GeneralSettingsSection(),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 32),
              SettingsConfigSection(
                l10n: l10n,
                exportController: _exportController,
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 32),
              SettingsClusterSection(
                l10n: l10n,
                exportController: _exportController,
              ),
              const SizedBox(height: 16),
              const Divider(),
              SettingsDiagnosticsSection(l10n: l10n),
              const SizedBox(height: 16),
              const Divider(),
              SettingsAboutAndUpdatesSection(l10n: l10n),
            ],
          ),
        ),
      ),
    );
  }
}
