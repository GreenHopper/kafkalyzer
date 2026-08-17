import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/ui/date_format_utils.dart';

class TimestampPickerField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool showInlineChips;
  final bool enabled;
  final Widget? suffixIcon;
  final String? selectedLabel;
  final ValueChanged<String?>? onLabelChanged;

  const TimestampPickerField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.suffixIcon,
    this.showInlineChips = false,
    this.selectedLabel,
    this.onLabelChanged,
  });

  @override
  State<TimestampPickerField> createState() => _TimestampPickerFieldState();
}

class _TimestampPickerFieldState extends State<TimestampPickerField> {
  String? _helperText;

  static const List<Map<String, dynamic>> _inlinePresets = [
    {'label': '1m', 'duration': Duration(minutes: 1)},
    {'label': '5m', 'duration': Duration(minutes: 5)},
    {'label': '15m', 'duration': Duration(minutes: 15)},
    {'label': '30m', 'duration': Duration(minutes: 30)},
    {'label': '1h', 'duration': Duration(hours: 1)},
    {'label': '6h', 'duration': Duration(hours: 6)},
    {'label': '12h', 'duration': Duration(hours: 12)},
    {'label': '24h', 'duration': Duration(hours: 24)},
  ];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateHelperText);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateHelperText();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    widget.controller.removeListener(_updateHelperText);
    super.dispose();
  }

  void _updateHelperText() {
    final text = widget.controller.text;
    if (text.isEmpty) {
      if (_helperText != null) setState(() => _helperText = null);
      return;
    }

    // Check if it's a valid date string
    final date = DateFormatUtils.parseDateTime(context, text);
    if (date != null) {
      final epoch = "Epoch: ${date.millisecondsSinceEpoch}";
      if (_helperText != epoch) {
        setState(() => _helperText = epoch);
      }
      return;
    }

    // Fallback: Check if it's an epoch (legacy support)
    final epoch = int.tryParse(text);
    if (epoch != null) {
      final d = DateTime.fromMillisecondsSinceEpoch(epoch);
      final formatted = DateFormatUtils.formatDateTime(
        context,
        d,
        withMilliseconds: false,
      );
      if (_helperText != formatted) {
        setState(() => _helperText = formatted);
      }
    } else {
      if (_helperText != null) setState(() => _helperText = null);
    }
  }

  Future<void> _pickDateTime() async {
    DateTime initialDate = DateTime.now();
    final text = widget.controller.text;

    final parsedDate = DateFormatUtils.parseDateTime(context, text);
    if (parsedDate != null) {
      initialDate = parsedDate;
    } else {
      final epoch = int.tryParse(text);
      if (epoch != null) {
        initialDate = DateTime.fromMillisecondsSinceEpoch(epoch);
      }
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1970),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );

      if (pickedTime != null && mounted) {
        final finalDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        widget.controller.text = DateFormatUtils.formatDateTime(
          context,
          finalDateTime,
        );
      }
    }
  }

  void _applyDuration(Duration duration) {
    final now = DateTime.now();
    final target = now.subtract(duration);
    widget.controller.text = DateFormatUtils.formatDateTime(context, target);
  }

  Future<void> _showQuickTimePicker() async {
    await showDialog(
      context: context,
      builder: (context) => _QuickTimeDialog(
        onApply: _applyDuration,
        onNow: () {
          widget.controller.text = DateFormatUtils.formatDateTime(
            context,
            DateTime.now(),
          );
        },
      ),
    );
  }

  Widget _buildField() {
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      onChanged: (_) {
        if (widget.onLabelChanged != null) {
          widget.onLabelChanged!(null);
        }
      },
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: true,
        border: const OutlineInputBorder(),
        helperText: _helperText,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.suffixIcon != null) widget.suffixIcon!,
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: widget.enabled ? _showQuickTimePicker : null,
              tooltip: "Quick Time Selection",
            ),
            IconButton(
              icon: const Icon(Icons.calendar_month),
              onPressed: widget.enabled ? _pickDateTime : null,
              tooltip: "Select Date & Time",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip(Duration duration, String label) {
    final isSelected = widget.selectedLabel == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      onSelected: widget.enabled
          ? (selected) {
              if (selected) {
                _applyDuration(duration);
                if (widget.onLabelChanged != null) {
                  widget.onLabelChanged!(label);
                }
              }
            }
          : null,
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSelected ? Colors.white : null,
      ),
      selectedColor: Theme.of(context).colorScheme.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildField(),
        if (widget.showInlineChips) ...[
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _inlinePresets.map((preset) {
                  return _buildTimeChip(
                    preset['duration'] as Duration,
                    preset['label'] as String,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _QuickTimeDialog extends StatefulWidget {
  final Function(Duration) onApply;
  final VoidCallback onNow;

  const _QuickTimeDialog({required this.onApply, required this.onNow});

  @override
  State<_QuickTimeDialog> createState() => _QuickTimeDialogState();
}

class _QuickTimeDialogState extends State<_QuickTimeDialog> {
  int _customValue = 5;
  String _customUnit = 'Minutes'; // Minutes, Hours, Days

  final List<Map<String, dynamic>> _presets = [
    {'label': '5 min ago', 'duration': const Duration(minutes: 5)},
    {'label': '15 min ago', 'duration': const Duration(minutes: 15)},
    {'label': '30 min ago', 'duration': const Duration(minutes: 30)},
    {'label': '1 hour ago', 'duration': const Duration(hours: 1)},
    {'label': '3 hours ago', 'duration': const Duration(hours: 3)},
    {'label': '12 hours ago', 'duration': const Duration(hours: 12)},
    {'label': '24 hours ago', 'duration': const Duration(hours: 24)},
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Quick Time Selection"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text("Now"),
                  avatar: const Icon(Icons.access_time, size: 16),
                  onPressed: () {
                    widget.onNow();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const Divider(),
            const Text(
              "Presets (Relative to Now)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((preset) {
                return ActionChip(
                  label: Text(preset['label']),
                  onPressed: () {
                    widget.onApply(preset['duration']);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text("Custom", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: _customValue.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _customValue = int.tryParse(val) ?? 0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _customUnit,
                  items: ['Minutes', 'Hours', 'Days']
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _customUnit = val);
                  },
                ),
                const SizedBox(width: 12),
                const Text("ago"),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Duration d;
            switch (_customUnit) {
              case 'Hours':
                d = Duration(hours: _customValue);
                break;
              case 'Days':
                d = Duration(days: _customValue);
                break;
              case 'Minutes':
              default:
                d = Duration(minutes: _customValue);
                break;
            }
            widget.onApply(d);
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
