import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_history/script_history_list.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_history/script_run_details_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:logger/logger.dart';

class ScriptHistoryView extends StatefulWidget {
  final Script script;
  final Function(ScriptRun)? onRerun;
  final Function(ScriptRun)? onLoadRun;
  final bool defaultToLoadResults;
  final ScriptRun? initialRun;

  const ScriptHistoryView({
    super.key,
    required this.script,
    this.onRerun,
    this.onLoadRun,
    this.defaultToLoadResults = false,
    this.initialRun,
  });

  @override
  State<ScriptHistoryView> createState() => _ScriptHistoryViewState();
}

class _ScriptHistoryViewState extends State<ScriptHistoryView> {
  final _logger = getIt<Logger>();
  List<ScriptRun>? _history;
  ScriptRun? _selectedRun;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    if (widget.initialRun != null) {
      _selectedRun = widget.initialRun;
    }
  }

  @override
  void didUpdateWidget(covariant ScriptHistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRun != null &&
        widget.initialRun != oldWidget.initialRun) {
      setState(() {
        _selectedRun = widget.initialRun;
      });
    }

    if (widget.script != oldWidget.script) {
      _selectedRun = null;
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    try {
      final history = await getIt<ScriptRunner>().getPastRuns(widget.script);
      // Sort by timestamp desc
      history.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mounted) {
        setState(() {
          _history = history;
        });
      }
    } catch (e) {
      _logger.e("Failed to load history", error: e);
    }
  }

  void _selectRun(ScriptRun run) {
    setState(() {
      _selectedRun = run;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedRun != null) {
      return ScriptRunDetailsView(
        key: ValueKey(_selectedRun!.id),
        run: _selectedRun!,
        script: widget.script,
        onBack: () {
          setState(() {
            _selectedRun = null;
          });
        },
      );
    }

    return ScriptHistoryList(
      script: widget.script,
      history: _history,
      onSelect: (run) {
        if (widget.defaultToLoadResults && widget.onLoadRun != null) {
          widget.onLoadRun!(run);
        } else {
          _selectRun(run);
        }
      },
      onRerun: widget.onRerun,
      onLoadRun: widget.onLoadRun,
      onRefresh: _loadHistory,
    );
  }
}
