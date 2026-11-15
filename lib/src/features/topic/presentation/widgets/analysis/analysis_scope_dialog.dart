import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/ui/date_format_utils.dart';
import 'package:kafkalyzer/src/ui/timestamp_picker_field.dart';
import 'package:material_ui/material_ui.dart';

String formatAnalysisScopeSummary(AnalysisScope scope, AppLocalizations? l10n) {
  final numFmt = NumberFormat.decimalPattern();
  final parts = <String>[];

  final limit = scope.messageLimit?.toInt();
  if (limit == null) {
    parts.add(l10n?.scopeSummaryAll ?? 'All messages');
  } else {
    final formatted = numFmt.format(limit);
    parts.add(
      scope.limitFrom == ScopeLimitFrom.newest
          ? (l10n?.scopeSummaryNewest(formatted) ?? 'Newest $formatted')
          : (l10n?.scopeSummaryOldest(formatted) ?? 'Oldest $formatted'),
    );
  }

  final partitions = scope.partitions;
  if (partitions != null && partitions.isNotEmpty) {
    final sorted = partitions.toList()..sort();
    final listStr = sorted.join(', ');
    parts.add(l10n?.scopeSummaryPartitions(listStr) ?? 'partitions $listStr');
  }

  final startMs = scope.startTimestampMs?.toInt();
  final endMs = scope.endTimestampMs?.toInt();
  if (startMs != null || endMs != null) {
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    final startStr = startMs != null
        ? fmt.format(DateTime.fromMillisecondsSinceEpoch(startMs).toLocal())
        : '…';
    final endStr = endMs != null
        ? fmt.format(DateTime.fromMillisecondsSinceEpoch(endMs).toLocal())
        : '…';
    parts.add('$startStr – $endStr');
  }

  return parts.join(' · ');
}

enum _ScopeMode { all, newest, oldest }

class AnalysisScopeDialog extends StatefulWidget {
  final AnalysisScope initialScope;
  final int partitionCount;

  const AnalysisScopeDialog({
    super.key,
    required this.initialScope,
    required this.partitionCount,
  });

  static Future<AnalysisScope?> show(
    BuildContext context, {
    required AnalysisScope initialScope,
    required int partitionCount,
  }) {
    return showDialog<AnalysisScope>(
      context: context,
      builder: (_) => AnalysisScopeDialog(
        initialScope: initialScope,
        partitionCount: partitionCount,
      ),
    );
  }

  @override
  State<AnalysisScopeDialog> createState() => _AnalysisScopeDialogState();
}

class _AnalysisScopeDialogState extends State<AnalysisScopeDialog> {
  static const int _defaultLimit = 10000;

  late _ScopeMode _mode;
  late final TextEditingController _countController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late bool _allPartitions;
  late Set<int> _selectedPartitions;
  bool _timestampsInitialized = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initialScope;
    if (s.messageLimit == null) {
      _mode = _ScopeMode.all;
    } else if (s.limitFrom == ScopeLimitFrom.oldest) {
      _mode = _ScopeMode.oldest;
    } else {
      _mode = _ScopeMode.newest;
    }
    _countController = TextEditingController(
      text: (s.messageLimit?.toInt() ?? _defaultLimit).toString(),
    );
    _startController = TextEditingController();
    _endController = TextEditingController();

    final initialParts = s.partitions;
    if (initialParts == null || widget.partitionCount <= 0) {
      _allPartitions = true;
      _selectedPartitions = {for (var i = 0; i < widget.partitionCount; i++) i};
    } else {
      _allPartitions = false;
      _selectedPartitions = initialParts
          .where((id) => id >= 0 && id < widget.partitionCount)
          .toSet();
    }

    _countController.addListener(_onFieldChanged);
    _startController.addListener(_onFieldChanged);
    _endController.addListener(_onFieldChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timestampsInitialized) return;
    _timestampsInitialized = true;
    final locale = Localizations.localeOf(context).toString();
    final fmt = DateFormat.yMd(locale).add_Hms();
    final s = widget.initialScope;
    if (s.startTimestampMs != null) {
      _startController.text = fmt.format(
        DateTime.fromMillisecondsSinceEpoch(
          s.startTimestampMs!.toInt(),
        ).toLocal(),
      );
    }
    if (s.endTimestampMs != null) {
      _endController.text = fmt.format(
        DateTime.fromMillisecondsSinceEpoch(
          s.endTimestampMs!.toInt(),
        ).toLocal(),
      );
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _countController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  _ValidationResult _validate(BuildContext context, AppLocalizations? l10n) {
    int? parsedCount;
    String? countError;
    if (_mode != _ScopeMode.all) {
      final raw = _countController.text.trim();
      final val = int.tryParse(raw);
      if (val == null || val <= 0) {
        countError =
            l10n?.scopeErrorInvalidCount ??
            'Enter a positive integer message limit.';
      } else {
        parsedCount = val;
      }
    }

    int? startMs;
    String? startError;
    final startText = _startController.text.trim();
    if (startText.isNotEmpty) {
      final dt = DateFormatUtils.parseDateTime(context, startText);
      if (dt == null) {
        startError =
            l10n?.scopeErrorInvalidStartTimestamp ??
            'Invalid start timestamp format.';
      } else {
        startMs = dt.toUtc().millisecondsSinceEpoch;
      }
    }

    int? endMs;
    String? endError;
    final endText = _endController.text.trim();
    if (endText.isNotEmpty) {
      final dt = DateFormatUtils.parseDateTime(context, endText);
      if (dt == null) {
        endError =
            l10n?.scopeErrorInvalidEndTimestamp ??
            'Invalid end timestamp format.';
      } else {
        endMs = dt.toUtc().millisecondsSinceEpoch;
      }
    }

    String? rangeError;
    if (startMs != null && endMs != null && startMs >= endMs) {
      rangeError =
          l10n?.scopeErrorStartAfterEnd ??
          'Start timestamp must be before end timestamp.';
    }

    String? partitionError;
    if (widget.partitionCount > 0 &&
        !_allPartitions &&
        _selectedPartitions.isEmpty) {
      partitionError =
          l10n?.scopeErrorNoPartitions ?? 'Select at least one partition.';
    }

    final isValid =
        countError == null &&
        startError == null &&
        endError == null &&
        rangeError == null &&
        partitionError == null;

    return _ValidationResult(
      isValid: isValid,
      count: parsedCount,
      startMs: startMs,
      endMs: endMs,
      countError: countError,
      startError: startError,
      endError: endError,
      rangeError: rangeError,
      partitionError: partitionError,
    );
  }

  AnalysisScope _buildScope(_ValidationResult v) {
    Int32List? partitions;
    if (widget.partitionCount > 0 &&
        !_allPartitions &&
        _selectedPartitions.length < widget.partitionCount) {
      final sorted = _selectedPartitions.toList()..sort();
      partitions = Int32List.fromList(sorted);
    }
    return AnalysisScope(
      partitions: partitions,
      startTimestampMs: v.startMs,
      endTimestampMs: v.endMs,
      messageLimit: _mode == _ScopeMode.all ? null : v.count,
      limitFrom: _mode == _ScopeMode.oldest
          ? ScopeLimitFrom.oldest
          : ScopeLimitFrom.newest,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final v = _validate(context, l10n);

    return AlertDialog(
      title: Text(l10n?.scopeDialogTitle ?? 'Analysis Scope'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_ScopeMode>(
                key: const Key('scope_mode_segmented_button'),
                segments: [
                  ButtonSegment(
                    value: _ScopeMode.all,
                    label: Text(l10n?.scopeModeAll ?? 'All'),
                  ),
                  ButtonSegment(
                    value: _ScopeMode.newest,
                    label: Text(l10n?.scopeModeNewest ?? 'Newest'),
                  ),
                  ButtonSegment(
                    value: _ScopeMode.oldest,
                    label: Text(l10n?.scopeModeOldest ?? 'Oldest'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (sel) {
                  setState(() {
                    _mode = sel.first;
                  });
                },
              ),
              if (_mode != _ScopeMode.all) ...[
                const SizedBox(height: 16),
                TextField(
                  key: const Key('scope_count_field'),
                  controller: _countController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText:
                        l10n?.scopeMessageLimitLabel ??
                        'Message limit (up to N offsets)',
                    helperText:
                        l10n?.scopeMessageLimitHelper ??
                        'Count is in offsets; compacted or transactional topics may yield fewer messages.',
                    helperMaxLines: 2,
                    errorText: v.countError,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                l10n?.scopeTimeRangeLabel ??
                    'Time range (optional, resolved via broker timestamp index)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TimestampPickerField(
                key: const Key('scope_start_timestamp_field'),
                controller: _startController,
                label: l10n?.scopeStartTimestampLabel ?? 'Start timestamp',
                showInlineChips: true,
              ),
              if (v.startError != null) ...[
                const SizedBox(height: 4),
                Text(
                  v.startError!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              TimestampPickerField(
                key: const Key('scope_end_timestamp_field'),
                controller: _endController,
                label: l10n?.scopeEndTimestampLabel ?? 'End timestamp',
              ),
              if (v.endError != null) ...[
                const SizedBox(height: 4),
                Text(
                  v.endError!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                ),
              ],
              if (v.rangeError != null) ...[
                const SizedBox(height: 4),
                Text(
                  v.rangeError!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                ),
              ],
              if (widget.partitionCount > 0) ...[
                const SizedBox(height: 16),
                Text(
                  l10n?.scopePartitionsLabel ?? 'Partitions',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FilterChip(
                      key: const Key('scope_all_partitions_chip'),
                      label: Text(
                        l10n?.scopeAllPartitionsChip ?? 'All partitions',
                      ),
                      selected: _allPartitions,
                      onSelected: (selected) {
                        setState(() {
                          _allPartitions = selected;
                          if (selected) {
                            _selectedPartitions = {
                              for (var i = 0; i < widget.partitionCount; i++) i,
                            };
                          } else {
                            _selectedPartitions.clear();
                          }
                        });
                      },
                    ),
                    for (var i = 0; i < widget.partitionCount; i++)
                      FilterChip(
                        key: Key('scope_partition_chip_$i'),
                        label: Text(l10n?.scopePartitionChipLabel(i) ?? 'P$i'),
                        selected:
                            _allPartitions || _selectedPartitions.contains(i),
                        onSelected: (selected) {
                          setState(() {
                            if (_allPartitions) {
                              _allPartitions = false;
                              _selectedPartitions = {
                                for (var j = 0; j < widget.partitionCount; j++)
                                  if (j != i || selected) j,
                              };
                            } else {
                              if (selected) {
                                _selectedPartitions.add(i);
                                if (_selectedPartitions.length ==
                                    widget.partitionCount) {
                                  _allPartitions = true;
                                }
                              } else {
                                _selectedPartitions.remove(i);
                              }
                            }
                          });
                        },
                      ),
                  ],
                ),
                if (v.partitionError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    v.partitionError!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.cancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const Key('scope_apply_button'),
          onPressed: v.isValid
              ? () => Navigator.of(context).pop(_buildScope(v))
              : null,
          child: Text(l10n?.scopeApplyButton ?? 'Apply'),
        ),
      ],
    );
  }
}

class _ValidationResult {
  final bool isValid;
  final int? count;
  final int? startMs;
  final int? endMs;
  final String? countError;
  final String? startError;
  final String? endError;
  final String? rangeError;
  final String? partitionError;

  const _ValidationResult({
    required this.isValid,
    this.count,
    this.startMs,
    this.endMs,
    this.countError,
    this.startError,
    this.endError,
    this.rangeError,
    this.partitionError,
  });
}
