import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/active_streams_list.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/search_results_view.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/search_stream_form.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';

class MultiSearchView extends StatefulWidget {
  const MultiSearchView({super.key});

  @override
  State<MultiSearchView> createState() => _MultiSearchViewState();
}

class _MultiSearchViewState extends State<MultiSearchView> {
  List<SearchTarget>? _selectedViewTargets;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final searchController = getIt<MultiSearchController>();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Configuration Panel (Left) ---
        Container(
          width: 420,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              right: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Text(
                      l10n.multiStreamConfig,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // --- Config List ---
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    SearchStreamForm(
                      onAddStreams: (targets) {
                        for (final target in targets) {
                          searchController.addTarget(target);
                        }
                        setState(
                          () => _selectedViewTargets = targets.length == 1
                              ? [targets.first]
                              : null,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    ActiveStreamsList(
                      selectedTargets: _selectedViewTargets,
                      onSelectTargets: (targets) =>
                          setState(() => _selectedViewTargets = targets),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // --- Results Panel (Right) ---
        Expanded(
          child: SearchResultsView(
            selectedTargets: _selectedViewTargets,
            onClearSelection: () => setState(() => _selectedViewTargets = null),
          ),
        ),
      ],
    );
  }
}
