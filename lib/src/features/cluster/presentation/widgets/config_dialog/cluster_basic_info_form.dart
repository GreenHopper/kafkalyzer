import 'package:flutter/material.dart';

class ClusterBasicInfoForm extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Cluster Name'),
            validator: (value) => value!.isEmpty ? 'Required' : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            controller: bootstrapServersController,
            decoration: const InputDecoration(
              labelText: 'Bootstrap Servers (e.g. localhost:9092)',
            ),
            validator: (value) => value!.isEmpty ? 'Required' : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            controller: schemaRegistryUrlController,
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
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            controller: schemaRegistryUsernameController,
            decoration: const InputDecoration(
              labelText: 'Schema Registry Username (Optional)',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            controller: schemaRegistryPasswordController,
            decoration: const InputDecoration(
              labelText: 'Schema Registry Password (Optional)',
            ),
            obscureText: true,
          ),
        ),
      ],
    );
  }
}
