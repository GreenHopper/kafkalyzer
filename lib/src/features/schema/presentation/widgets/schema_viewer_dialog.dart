import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/topic_schema_inspector_view.dart';

/// Modal dialog wrapper for standalone schema inspection, delegating display
/// to [TopicSchemaInspectorView].
class SchemaViewerDialog extends StatelessWidget {
  final ClusterProfile profile;
  final String topicName;
  final SchemaController controller;
  final ValueChanged<String>? onPinToColumn;
  final ValueChanged<String>? onFilterByField;

  const SchemaViewerDialog({
    super.key,
    required this.profile,
    required this.topicName,
    required this.controller,
    this.onPinToColumn,
    this.onFilterByField,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width * 0.9,
          maxHeight: size.height * 0.9,
          minWidth: 800 > size.width * 0.9 ? size.width * 0.9 : 800,
          minHeight: 500 > size.height * 0.9 ? size.height * 0.9 : 500,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Flexible(child: _buildHeader(context)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: AppLocalizations.of(context)?.close ?? 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: TopicSchemaInspectorView(
                profile: profile,
                topicName: topicName,
                controller: controller,
                onPinToColumn: onPinToColumn,
                onFilterByField: onFilterByField,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.schemaViewerTitle ?? "Schema Viewer",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          "${l10n?.topicCol ?? 'Topic'}: $topicName",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
