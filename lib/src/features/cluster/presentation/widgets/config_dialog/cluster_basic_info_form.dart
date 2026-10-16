import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/password_form_field.dart';

class ClusterBasicInfoForm extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController bootstrapServersController;
  final TextEditingController schemaRegistryUrlController;
  final TextEditingController schemaRegistryUsernameController;
  final TextEditingController schemaRegistryPasswordController;

  const ClusterBasicInfoForm({
    super.key,
    required this.nameController,
    required this.bootstrapServersController,
    required this.schemaRegistryUrlController,
    required this.schemaRegistryUsernameController,
    required this.schemaRegistryPasswordController,
  });

  @override
  State<ClusterBasicInfoForm> createState() => _ClusterBasicInfoFormState();
}

class _ClusterBasicInfoFormState extends State<ClusterBasicInfoForm> {
  bool _isSchemaExpanded = false;

  @override
  void initState() {
    super.initState();
    _isSchemaExpanded =
        widget.schemaRegistryUsernameController.text.isNotEmpty ||
        widget.schemaRegistryPasswordController.text.isNotEmpty;
    widget.schemaRegistryUrlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    widget.schemaRegistryUrlController.removeListener(_onUrlChanged);
    super.dispose();
  }

  void _onUrlChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasSchemaUrl =
        widget.schemaRegistryUrlController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            controller: widget.nameController,
            decoration: const InputDecoration(labelText: 'Cluster Name'),
            validator: (value) => value!.isEmpty ? 'Required' : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            controller: widget.bootstrapServersController,
            decoration: const InputDecoration(
              labelText: 'Bootstrap Servers (e.g. localhost:9092)',
            ),
            validator: (value) => value!.isEmpty ? 'Required' : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            controller: widget.schemaRegistryUrlController,
            decoration: const InputDecoration(
              labelText: 'Schema Registry URL (Optional)',
              hintText: 'e.g. http://localhost:8081',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return null;
              final trimmed = value.trim();
              final uri = Uri.tryParse(trimmed);
              if (uri == null) return "Invalid URL format";

              if (trimmed.contains(RegExp(r'\.\d{4,5}$'))) {
                return "Likely typo: use ':' for port instead of '.'";
              }

              if (!trimmed.startsWith("http://") &&
                  !trimmed.startsWith("https://")) {
                return "Missing protocol (http:// or https://)";
              }

              return null;
            },
          ),
        ),
        if (hasSchemaUrl || _isSchemaExpanded) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _isSchemaExpanded = !_isSchemaExpanded;
                });
              },
              child: Row(
                children: [
                  Icon(
                    _isSchemaExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n?.schemaRegistryCredentialsOptional ??
                        'Schema Registry Credentials (Optional)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
          if (_isSchemaExpanded) ...[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                controller: widget.schemaRegistryUsernameController,
                decoration: const InputDecoration(
                  labelText: 'Schema Registry Username (Optional)',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: PasswordFormField(
                controller: widget.schemaRegistryPasswordController,
                labelText: 'Schema Registry Password (Optional)',
              ),
            ),
          ],
        ],
      ],
    );
  }
}
