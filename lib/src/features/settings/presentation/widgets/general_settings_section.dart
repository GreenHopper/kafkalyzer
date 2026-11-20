import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/services/session_restore_service.dart';
import 'package:kafkalyzer/src/services/topic_analysis_history_service.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/int_setting_field.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/message_buffer_limit_field.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/section_reset_confirmation.dart';

class GeneralSettingsSection extends StatefulWidget {
  const GeneralSettingsSection({super.key});

  @override
  State<GeneralSettingsSection> createState() =>
      GeneralSettingsSectionState();
}

class GeneralSettingsSectionState extends State<GeneralSettingsSection> {
  SharedPreferences? _prefs;
  final TextEditingController _dirController = TextEditingController();
  int _resetGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _dirController.text = prefs.getString('general_default_output_dir') ?? '';
    });
  }

  Future<void> _confirmDeleteAnalysisHistory(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteSavedAnalysisReportsConfirmTitle),
        content: Text(l10n.deleteSavedAnalysisReportsConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await getIt<TopicAnalysisHistoryService>().clearAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deleteSavedAnalysisReportsSuccess)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.deleteSavedAnalysisReportsFailed(e.toString())),
        ),
      );
    }
  }

  @override
  void dispose() {
    _dirController.dispose();
    super.dispose();
  }

  Future<void> _resetGeneral() async {
    await getIt<SettingsService>().resetGeneralSettings();
    if (getIt.isRegistered<MultiSearchController>()) {
      getIt<MultiSearchController>().loadDirectory();
    }
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _dirController.text = prefs.getString('general_default_output_dir') ?? '';
      _resetGeneration++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = _prefs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.general,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              key: const Key('reset_general_button'),
              onPressed: () => confirmSectionReset(
                context,
                l10n,
                l10n.general,
                _resetGeneral,
              ),
              child: Text(l10n.resetToDefaults),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (prefs == null)
          const SizedBox.shrink()
        else ...[
          TextField(
            controller: _dirController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: l10n.defaultScriptOutputDir,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.folder_open),
                tooltip: l10n.browseDirectoryTooltip,
                onPressed: () async {
                  final selected = await FilePicker.getDirectoryPath();
                  if (selected != null) {
                    await prefs.setString(
                      'general_default_output_dir',
                      selected,
                    );
                    _dirController.text = selected;
                    if (getIt.isRegistered<MultiSearchController>()) {
                      getIt<MultiSearchController>().loadDirectory();
                    }
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          IntSettingField(
            fieldKey: const Key('default_result_limit_field'),
            setting: SettingsService.defaultResultLimitSetting,
            label: l10n.defaultResultLimitLabel,
            prefs: prefs,
            resetGeneration: _resetGeneration,
          ),
          const SizedBox(height: 16),
          IntSettingField(
            fieldKey: const Key('partition_skew_threshold_field'),
            setting: SettingsService.partitionSkewThresholdSetting,
            label: l10n.partitionOffsetSkewThresholdLabel,
            prefs: prefs,
            resetGeneration: _resetGeneration,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: IntSettingField(
                  fieldKey: const Key('max_run_history_field'),
                  setting: SettingsService.maxRunHistorySetting,
                  label: l10n.maxScriptRunHistory,
                  prefs: prefs,
                  resetGeneration: _resetGeneration,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: IntSettingField(
                  fieldKey: const Key('analysis_history_per_topic_field'),
                  setting: SettingsService.analysisHistoryPerTopicSetting,
                  label: l10n.analysisHistoryPerTopicLabel,
                  prefs: prefs,
                  resetGeneration: _resetGeneration,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: IntSettingField(
                  fieldKey: const Key('analysis_confirm_threshold_field'),
                  setting: SettingsService.analysisConfirmThresholdSetting,
                  label: l10n.analysisConfirmThresholdLabel,
                  prefs: prefs,
                  resetGeneration: _resetGeneration,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: IntSettingField(
                  fieldKey: const Key('max_concurrent_lag_queries_field'),
                  setting: SettingsService.maxConcurrentLagQueriesSetting,
                  label: l10n.maxConcurrentLagQueries,
                  prefs: prefs,
                  resetGeneration: _resetGeneration,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('delete_saved_analysis_reports_button'),
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: Text(l10n.deleteSavedAnalysisReports),
              onPressed: () => _confirmDeleteAnalysisHistory(l10n),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: IntSettingField(
                  fieldKey: const Key('lag_warn_threshold_field'),
                  setting: SettingsService.lagWarnThresholdSetting,
                  label: l10n.lagWarnThresholdLabel,
                  prefs: prefs,
                  resetGeneration: _resetGeneration,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: MessageBufferLimitField(
                  key: ValueKey('msg_buf_$_resetGeneration'),
                  initialValue:
                      SettingsService.parseMessageBufferLimit(
                        prefs
                                .getInt(SettingsService.messageBufferLimitKey)
                                ?.toString() ??
                            '',
                      ) ??
                      SettingsService.defaultMessageBufferLimit,
                  l10n: l10n,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            key: const Key('restore_open_tabs_switch'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.restoreOpenTabsOnStartup),
            subtitle: Text(l10n.restoreOpenTabsOnStartupDescription),
            value:
                prefs.getBool(SessionRestoreService.prefRestoreEnabled) ?? true,
            onChanged: (bool value) async {
              await getIt<SessionRestoreService>().setRestorationEnabled(value);
              setState(() {});
            },
          ),
        ],
      ],
    );
  }
}
