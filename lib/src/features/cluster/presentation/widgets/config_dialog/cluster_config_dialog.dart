import 'package:material_ui/material_ui.dart';
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
  late final TextEditingController _schemaRegistryUsernameController;
  late final TextEditingController _schemaRegistryPasswordController;
  late final TextEditingController _saslKerberosServiceNameController;
  late final TextEditingController _saslKerberosKeytabController;
  late final TextEditingController _saslKerberosPrincipalController;
  late final TextEditingController _saslKerberosConfController;
  late final TextEditingController _saslOauthbearerTokenController;
  late final TextEditingController _sslPemCertificateLocationController;
  late final TextEditingController _sslPemKeyLocationController;
  late final TextEditingController _sslPemKeyPasswordController;

  String _securityProtocol = "PLAINTEXT";
  String? _mechanism = "PLAIN";

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.cluster?.name ?? "");
    _bootstrapServersController = TextEditingController(
      text: widget.cluster?.bootstrapServers ?? "",
    );
    _saslUsernameController = TextEditingController(
      text: widget.cluster?.saslUsername ?? "",
    );
    _saslPasswordController = TextEditingController(
      text: widget.cluster?.saslPassword ?? "",
    );
    _schemaRegistryUrlController = TextEditingController(
      text: widget.cluster?.schemaRegistryUrl ?? "",
    );
    _sslKeystoreLocationController = TextEditingController(
      text: widget.cluster?.sslKeystoreLocation ?? "",
    );
    _sslKeystorePasswordController = TextEditingController(
      text: widget.cluster?.sslKeystorePassword ?? "",
    );
    _sslTruststoreLocationController = TextEditingController(
      text: widget.cluster?.sslTruststoreLocation ?? "",
    );
    _sslTruststorePasswordController = TextEditingController(
      text: widget.cluster?.sslTruststorePassword ?? "",
    );
    _schemaRegistryUsernameController = TextEditingController(
      text: widget.cluster?.schemaRegistryUsername ?? "",
    );
    _schemaRegistryPasswordController = TextEditingController(
      text: widget.cluster?.schemaRegistryPassword ?? "",
    );
    _saslKerberosServiceNameController = TextEditingController(
      text: widget.cluster?.saslKerberosServiceName ?? "",
    );
    _saslKerberosKeytabController = TextEditingController(
      text: widget.cluster?.saslKerberosKeytab ?? "",
    );
    _saslKerberosPrincipalController = TextEditingController(
      text: widget.cluster?.saslKerberosPrincipal ?? "",
    );
    _saslKerberosConfController = TextEditingController(
      text: widget.cluster?.saslKerberosConf ?? "",
    );
    _saslOauthbearerTokenController = TextEditingController(
      text: widget.cluster?.saslOauthbearerToken ?? "",
    );
    _sslPemCertificateLocationController = TextEditingController(
      text: widget.cluster?.sslPemCertificateLocation ?? "",
    );
    _sslPemKeyLocationController = TextEditingController(
      text: widget.cluster?.sslPemKeyLocation ?? "",
    );
    _sslPemKeyPasswordController = TextEditingController(
      text: widget.cluster?.sslPemKeyPassword ?? "",
    );

    if (widget.cluster != null) {
      if (widget.cluster!.securityProtocol != null) {
        _securityProtocol = widget.cluster!.securityProtocol!;
      }
      if (widget.cluster!.mechanism != null) {
        _mechanism = widget.cluster!.mechanism;
      }
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
    _schemaRegistryUsernameController.dispose();
    _schemaRegistryPasswordController.dispose();
    _saslKerberosServiceNameController.dispose();
    _saslKerberosKeytabController.dispose();
    _saslKerberosPrincipalController.dispose();
    _saslKerberosConfController.dispose();
    _saslOauthbearerTokenController.dispose();
    _sslPemCertificateLocationController.dispose();
    _sslPemKeyLocationController.dispose();
    _sslPemKeyPasswordController.dispose();
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
                  schemaRegistryUsernameController:
                      _schemaRegistryUsernameController,
                  schemaRegistryPasswordController:
                      _schemaRegistryPasswordController,
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: DropdownButtonFormField<String>(
                    initialValue: _securityProtocol,
                    decoration: const InputDecoration(
                      labelText: 'Security Protocol',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: "PLAINTEXT",
                        child: Text("PLAINTEXT"),
                      ),
                      DropdownMenuItem(
                        value: "SASL_PLAINTEXT",
                        child: Text("SASL_PLAINTEXT"),
                      ),
                      DropdownMenuItem(
                        value: "SASL_SSL",
                        child: Text("SASL_SSL"),
                      ),
                      DropdownMenuItem(value: "SSL", child: Text("SSL")),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _securityProtocol = value!;
                      });
                    },
                  ),
                ),
                if (_securityProtocol.startsWith("SASL")) ...[
                  ClusterSaslForm(
                    mechanism: _mechanism,
                    onMechanismChanged: (value) =>
                        setState(() => _mechanism = value),
                    usernameController: _saslUsernameController,
                    passwordController: _saslPasswordController,
                    kerberosServiceNameController:
                        _saslKerberosServiceNameController,
                    kerberosKeytabController: _saslKerberosKeytabController,
                    kerberosPrincipalController:
                        _saslKerberosPrincipalController,
                    kerberosConfController: _saslKerberosConfController,
                    oauthbearerTokenController: _saslOauthbearerTokenController,
                  ),
                ],
                if (_securityProtocol == "SSL" ||
                    _securityProtocol == "SASL_SSL") ...[
                  ClusterSslForm(
                    keystoreLocationController: _sslKeystoreLocationController,
                    keystorePasswordController: _sslKeystorePasswordController,
                    truststoreLocationController:
                        _sslTruststoreLocationController,
                    truststorePasswordController:
                        _sslTruststorePasswordController,
                    pemCertificateLocationController:
                        _sslPemCertificateLocationController,
                    pemKeyLocationController: _sslPemKeyLocationController,
                    pemKeyPasswordController: _sslPemKeyPasswordController,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final profile = ClusterProfile(
                name: _nameController.text,
                bootstrapServers: _bootstrapServersController.text,
                saslUsername: _saslUsernameController.text.isNotEmpty
                    ? _saslUsernameController.text
                    : null,
                saslPassword: _saslPasswordController.text.isNotEmpty
                    ? _saslPasswordController.text
                    : null,
                mechanism: _securityProtocol.startsWith("SASL")
                    ? _mechanism
                    : null,
                securityProtocol: _securityProtocol,
                schemaRegistryUrl: _schemaRegistryUrlController.text.isNotEmpty
                    ? _schemaRegistryUrlController.text
                    : null,
                sslKeystoreLocation:
                    _sslKeystoreLocationController.text.isNotEmpty
                    ? _sslKeystoreLocationController.text
                    : null,
                sslKeystorePassword:
                    _sslKeystorePasswordController.text.isNotEmpty
                    ? _sslKeystorePasswordController.text
                    : null,
                sslTruststoreLocation:
                    _sslTruststoreLocationController.text.isNotEmpty
                    ? _sslTruststoreLocationController.text
                    : null,
                sslTruststorePassword:
                    _sslTruststorePasswordController.text.isNotEmpty
                    ? _sslTruststorePasswordController.text
                    : null,
                schemaRegistryUsername:
                    _schemaRegistryUsernameController.text.isNotEmpty
                    ? _schemaRegistryUsernameController.text
                    : null,
                schemaRegistryPassword:
                    _schemaRegistryPasswordController.text.isNotEmpty
                    ? _schemaRegistryPasswordController.text
                    : null,
                saslKerberosServiceName:
                    _saslKerberosServiceNameController.text.isNotEmpty
                    ? _saslKerberosServiceNameController.text
                    : null,
                saslKerberosKeytab:
                    _saslKerberosKeytabController.text.isNotEmpty
                    ? _saslKerberosKeytabController.text
                    : null,
                saslKerberosPrincipal:
                    _saslKerberosPrincipalController.text.isNotEmpty
                    ? _saslKerberosPrincipalController.text
                    : null,
                saslKerberosConf: _saslKerberosConfController.text.isNotEmpty
                    ? _saslKerberosConfController.text
                    : null,
                saslOauthbearerToken:
                    _saslOauthbearerTokenController.text.isNotEmpty
                    ? _saslOauthbearerTokenController.text
                    : null,
                sslPemCertificateLocation:
                    _sslPemCertificateLocationController.text.isNotEmpty
                    ? _sslPemCertificateLocationController.text
                    : null,
                sslPemKeyLocation: _sslPemKeyLocationController.text.isNotEmpty
                    ? _sslPemKeyLocationController.text
                    : null,
                sslPemKeyPassword: _sslPemKeyPasswordController.text.isNotEmpty
                    ? _sslPemKeyPasswordController.text
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
