import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IntSettingField extends StatefulWidget {
  final Key? fieldKey;
  final IntSetting setting;
  final String label;
  final SharedPreferences prefs;
  final int resetGeneration;

  const IntSettingField({super.key, 
    this.fieldKey,
    required this.setting,
    required this.label,
    required this.prefs,
    required this.resetGeneration,
  });

  @override
  State<IntSettingField> createState() => IntSettingFieldState();
}

class IntSettingFieldState extends State<IntSettingField> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: SettingsService.readInt(widget.prefs, widget.setting).toString(),
    );
  }

  @override
  void didUpdateWidget(covariant IntSettingField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetGeneration != oldWidget.resetGeneration) {
      _controller.text = SettingsService.readInt(
        widget.prefs,
        widget.setting,
      ).toString();
      _errorText = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextField(
      key: widget.fieldKey,
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        helperText: l10n.intSettingRangeHelper(
          widget.setting.min,
          widget.setting.max,
          widget.setting.defaultValue,
        ),
        errorText: _errorText,
      ),
      onChanged: (value) {
        final parsed = SettingsService.parseInt(value, widget.setting);
        if (parsed == null) {
          setState(() {
            _errorText = l10n.intSettingRangeError(
              widget.setting.min,
              widget.setting.max,
            );
          });
          return;
        }
        if (_errorText != null) {
          setState(() {
            _errorText = null;
          });
        }
        getIt<SettingsService>().writeInt(widget.setting, parsed);
      },
    );
  }
}
