import 'package:flutter/material.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'cluster_basic_info_form.dart';
import 'cluster_sasl_form.dart';
import 'cluster_ssl_form.dart';

class ClusterConfigDialog extends StatefulWidget {
  final ClusterProfile? cluster;

  const ClusterConfigDialog({super.key, this.cluster});

  @override
  State<ClusterConfigDialog> createState() => _ClusterConfigDialogState();
}

class _ClusterConfigDialogState extends State<ClusterConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _bootstrapServersController;
  late final TextEditingController _saslUsernameController;
  late final TextEditingController _saslPasswordController;
  late final TextEditingController _schemaRegistryUrlController;
  late final TextEditingController _sslKeystoreLocationController;
  late final TextEditingController _sslKeystorePasswordController;
  late final TextEditingController _sslTruststoreLocationController;
  late final TextEditingController _sslTruststorePasswordController;

  String _securityProtocol = "PLAINTEXT";
  String? _mechanism = "PLAIN";

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.cluster?.name ?? "");
    _bootstrapServersController = TextEditingController(text: widget.cluster?.bootstrapServers ?? "");
    _saslUsernameController = TextEditingController(text: widget.cluster?.saslUsername ?? "");
    _saslPasswordController = TextEditingController(text: widget.cluster?.saslPassword ?? "");
    _schemaRegistryUrlController = TextEditingController(text: widget.cluster?.schemaRegistryUrl ?? "");
    _sslKeystoreLocationController = TextEditingController(text: widget.cluster?.sslKeystoreLocation ?? "");
    _sslKeystorePasswordController = TextEditingController(text: widget.cluster?.sslKeystorePassword ?? "");
    _sslTruststoreLocationController = TextEditingController(text: widget.cluster?.sslTruststoreLocation ?? "");
    _sslTruststorePasswordController = TextEditingController(text: widget.cluster?.sslTruststorePassword ?? "");

    if (widget.cluster != null) {
      if (widget.cluster!.securityProtocol != null) {
        _securityProtocol = widget.cluster!.securityProtocol!;
      }
      if (widget.cluster!.mechanism != null) {
        _mechanism = widget.cluster!.mechanism;
      }
      // Text controllers initialized above already handle null checks via defaults
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bootstrapServersController.dispose();
    _saslUsernameController.dispose();
    _saslPasswordController.dispose();
    _schemaRegistryUrlController.dispose();
    _sslKeystoreLocationController.dispose();
    _sslKeystorePasswordController.dispose();
    _sslTruststoreLocationController.dispose();
    _sslTruststorePasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.cluster == null ? 'Add Cluster' : 'Edit Cluster'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClusterBasicInfoForm(
                  nameController: _nameController,
                  bootstrapServersController: _bootstrapServersController,
                  schemaRegistryUrlController: _schemaRegistryUrlController,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _securityProtocol,
                  decoration: const InputDecoration(labelText: 'Security Protocol'),
                  items: const [
                    DropdownMenuItem(value: "PLAINTEXT", child: Text("PLAINTEXT")),
                    DropdownMenuItem(value: "SASL_PLAINTEXT", child: Text("SASL_PLAINTEXT")),
                    DropdownMenuItem(value: "SASL_SSL", child: Text("SASL_SSL")),
                    DropdownMenuItem(value: "SSL", child: Text("SSL")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _securityProtocol = value!;
                    });
                  },
                ),
                if (_securityProtocol.startsWith("SASL")) ...[
                  ClusterSaslForm(
                    mechanism: _mechanism,
                    onMechanismChanged: (value) => setState(() => _mechanism = value),
                    usernameController: _saslUsernameController,
                    passwordController: _saslPasswordController,
                  ),
                ],
                if (_securityProtocol == "SSL" || _securityProtocol == "SASL_SSL") ...[
                  ClusterSslForm(
                    keystoreLocationController: _sslKeystoreLocationController,
                    keystorePasswordController: _sslKeystorePasswordController,
                    truststoreLocationController: _sslTruststoreLocationController,
                    truststorePasswordController: _sslTruststorePasswordController,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final profile = ClusterProfile(
                name: _nameController.text,
                bootstrapServers: _bootstrapServersController.text,
                saslUsername: _saslUsernameController.text.isNotEmpty ? _saslUsernameController.text : null,
                saslPassword: _saslPasswordController.text.isNotEmpty ? _saslPasswordController.text : null,
                mechanism: _securityProtocol.startsWith("SASL") ? _mechanism : null,
                securityProtocol: _securityProtocol,
                schemaRegistryUrl: _schemaRegistryUrlController.text.isNotEmpty
                    ? _schemaRegistryUrlController.text
                    : null,
                sslKeystoreLocation: _sslKeystoreLocationController.text.isNotEmpty
                    ? _sslKeystoreLocationController.text
                    : null,
                sslKeystorePassword: _sslKeystorePasswordController.text.isNotEmpty
                    ? _sslKeystorePasswordController.text
                    : null,
                sslTruststoreLocation: _sslTruststoreLocationController.text.isNotEmpty
                    ? _sslTruststoreLocationController.text
                    : null,
                sslTruststorePassword: _sslTruststorePasswordController.text.isNotEmpty
                    ? _sslTruststorePasswordController.text
                    : null,
              );
              Navigator.pop(context, profile);
            }
          },
          child: Text(widget.cluster == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
