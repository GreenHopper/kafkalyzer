import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

bool hasSchema(
  SchemaController controller,
  ClusterProfile cluster,
  String topicName,
) {
  final schemas = controller.getSchemas(cluster);
  if (schemas == null) return false;
  return schemas.contains("$topicName-key") ||
      schemas.contains("$topicName-value");
}

String splitPolicy(String policy) {
  if (policy.length > 15) return "Policy: ...";
  return policy;
}

String formatRetention(String ms) {
  try {
    final val = int.parse(ms);
    if (val == -1) return "Infinite";
    final hours = val / 3600000;
    if (hours >= 24) {
      return "${(hours / 24).toStringAsFixed(1)} days";
    }
    return "${hours.toStringAsFixed(1)} hrs";
  } catch (_) {
    return ms;
  }
}

Future<void> confirmCloseTab(
  BuildContext context, {
  required bool isOperationRunning,
  required VoidCallback onClose,
}) async {
  if (!isOperationRunning) {
    onClose();
    return;
  }

  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n?.operationInProgress ?? 'Operation in Progress'),
      content: Text(
        l10n?.operationInProgressMessage ??
            'A search or analysis is still running on this tab. '
                'Close the tab and cancel the operation?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n?.cancel ?? 'Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n?.close ?? 'Close'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    onClose();
  }
}
