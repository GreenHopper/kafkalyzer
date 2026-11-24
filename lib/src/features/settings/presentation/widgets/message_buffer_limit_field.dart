import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';

class MessageBufferLimitField extends StatefulWidget {
  final int initialValue;
  final AppLocalizations l10n;

  const MessageBufferLimitField({
    super.key,
    required this.initialValue,
    required this.l10n,
  });

  @override
  State<MessageBufferLimitField> createState() =>
      _MessageBufferLimitFieldState();
}

class _MessageBufferLimitFieldState extends State<MessageBufferLimitField> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('message_buffer_limit_field'),
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: widget.l10n.messageBufferLimitLabel,
        border: const OutlineInputBorder(),
        helperText: widget.l10n.messageBufferLimitHelper,
        errorText: _errorText,
      ),
      onChanged: (value) {
        final parsed = SettingsService.parseMessageBufferLimit(value);
        if (parsed == null) {
          setState(() {
            _errorText = widget.l10n.messageBufferLimitError;
          });
          return;
        }
        setState(() {
          _errorText = null;
        });
        getIt<SettingsService>().setMessageBufferLimit(parsed);
      },
    );
  }
}
