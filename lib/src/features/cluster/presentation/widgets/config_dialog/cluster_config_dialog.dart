import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_basic_info_form.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_sasl_form.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_ssl_form.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/read_only_guidance_dialog.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';

class ClusterConfigDialog extends StatefulWidget {
  final ClusterProfile? cluster;

  const ClusterConfigDialog({super.key, this.cluster});

  @override
  State<ClusterConfigDialog> createState() => _ClusterConfigDialogState();
}

class _ClusterConfigDialogState extends State<ClusterConfigDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _bootstrapServersController;
  late TextEditingController _saslUsernameController;
  late TextEditingController _saslPasswordController;
  late TextEditingController _schemaRegistryUrlController;
  late TextEditingController _sslKeystoreLocationController;
  late TextEditingController _sslKeystorePasswordController;
  late TextEditingController _sslTruststoreLocationController;
  late TextEditingController _sslTruststorePasswordController;
  late TextEditingController _schemaRegistryUsernameController;
  late TextEditingController _schemaRegistryPasswordController;
  late TextEditingController _saslKerberosServiceNameController;
  late TextEditingController _saslKerberosKeytabController;
  late TextEditingController _saslKerberosPrincipalController;
  late TextEditingController _saslKerberosConfController;
  late TextEditingController _saslOauthbearerTokenController;
  late TextEditingController _sslPemCertificateLocationController;
  late TextEditingController _sslPemKeyLocationController;
  late TextEditingController _sslPemKeyPasswordController;

  late String _securityProtocol;
  String? _mechanism;

  bool _isTestingConnection = false;
  String? _testConnectionStatus;
  bool? _testConnectionSuccess;

  @override
  void initState() {
    super.initState();
    final c = widget.cluster;
    _nameController = TextEditingController(text: c?.name ?? '');
    _bootstrapServersController = TextEditingController(
      text: c?.bootstrapServers ?? '',
    );
    _saslUsernameController = TextEditingController(
      text: c?.saslUsername ?? '',
    );
    _saslPasswordController = TextEditingController(
      text: c?.saslPassword ?? '',
    );
    _schemaRegistryUrlController = TextEditingController(
      text: c?.schemaRegistryUrl ?? '',
    );
    _sslKeystoreLocationController = TextEditingController(
      text: c?.sslKeystoreLocation ?? '',
    );
    _sslKeystorePasswordController = TextEditingController(
      text: c?.sslKeystorePassword ?? '',
    );
    _sslTruststoreLocationController = TextEditingController(
      text: c?.sslTruststoreLocation ?? '',
    );
    _sslTruststorePasswordController = TextEditingController(
      text: c?.sslTruststorePassword ?? '',
    );
    _schemaRegistryUsernameController = TextEditingController(
      text: c?.schemaRegistryUsername ?? '',
    );
    _schemaRegistryPasswordController = TextEditingController(
      text: c?.schemaRegistryPassword ?? '',
    );
    _saslKerberosServiceNameController = TextEditingController(
      text: c?.saslKerberosServiceName ?? '',
    );
    _saslKerberosKeytabController = TextEditingController(
      text: c?.saslKerberosKeytab ?? '',
    );
    _saslKerberosPrincipalController = TextEditingController(
      text: c?.saslKerberosPrincipal ?? '',
    );
    _saslKerberosConfController = TextEditingController(
      text: c?.saslKerberosConf ?? '',
    );
    _saslOauthbearerTokenController = TextEditingController(
      text: c?.saslOauthbearerToken ?? '',
    );
    _sslPemCertificateLocationController = TextEditingController(
      text: c?.sslPemCertificateLocation ?? '',
    );
    _sslPemKeyLocationController = TextEditingController(
      text: c?.sslPemKeyLocation ?? '',
    );
    _sslPemKeyPasswordController = TextEditingController(
      text: c?.sslPemKeyPassword ?? '',
    );

    _securityProtocol = c?.securityProtocol ?? 'PLAINTEXT';
    _mechanism = c?.mechanism ?? 'PLAIN';
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

  ClusterProfile _buildCandidateProfile() {
    return ClusterProfile(
      name: _nameController.text.trim(),
      bootstrapServers: _bootstrapServersController.text.trim(),
      saslUsername: _saslUsernameController.text.isNotEmpty
          ? _saslUsernameController.text
          : null,
      saslPassword: _saslPasswordController.text.isNotEmpty
          ? _saslPasswordController.text
          : null,
      mechanism: _securityProtocol.startsWith("SASL") ? _mechanism : null,
      securityProtocol: _securityProtocol,
      schemaRegistryUrl: _schemaRegistryUrlController.text.trim().isNotEmpty
          ? _schemaRegistryUrlController.text.trim()
          : null,
      sslKeystoreLocation: _sslKeystoreLocationController.text.trim().isNotEmpty
          ? _sslKeystoreLocationController.text.trim()
          : null,
      sslKeystorePassword: _sslKeystorePasswordController.text.isNotEmpty
          ? _sslKeystorePasswordController.text
          : null,
      sslTruststoreLocation:
          _sslTruststoreLocationController.text.trim().isNotEmpty
          ? _sslTruststoreLocationController.text.trim()
          : null,
      sslTruststorePassword: _sslTruststorePasswordController.text.isNotEmpty
          ? _sslTruststorePasswordController.text
          : null,
      schemaRegistryUsername: _schemaRegistryUsernameController.text.isNotEmpty
          ? _schemaRegistryUsernameController.text
          : null,
      schemaRegistryPassword: _schemaRegistryPasswordController.text.isNotEmpty
          ? _schemaRegistryPasswordController.text
          : null,
      saslKerberosServiceName:
          _saslKerberosServiceNameController.text.isNotEmpty
          ? _saslKerberosServiceNameController.text
          : null,
      saslKerberosKeytab: _saslKerberosKeytabController.text.trim().isNotEmpty
          ? _saslKerberosKeytabController.text.trim()
          : null,
      saslKerberosPrincipal: _saslKerberosPrincipalController.text.isNotEmpty
          ? _saslKerberosPrincipalController.text
          : null,
      saslKerberosConf: _saslKerberosConfController.text.trim().isNotEmpty
          ? _saslKerberosConfController.text.trim()
          : null,
      saslOauthbearerToken: _saslOauthbearerTokenController.text.isNotEmpty
          ? _saslOauthbearerTokenController.text
          : null,
      sslPemCertificateLocation:
          _sslPemCertificateLocationController.text.trim().isNotEmpty
          ? _sslPemCertificateLocationController.text.trim()
          : null,
      sslPemKeyLocation: _sslPemKeyLocationController.text.trim().isNotEmpty
          ? _sslPemKeyLocationController.text.trim()
          : null,
      sslPemKeyPassword: _sslPemKeyPasswordController.text.isNotEmpty
          ? _sslPemKeyPasswordController.text
          : null,
    );
  }

  Future<void> _handleTestConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    setState(() {
      _isTestingConnection = true;
      _testConnectionStatus = null;
      _testConnectionSuccess = null;
    });

    try {
      final candidate = _buildCandidateProfile();
      final success = await getIt<KafkaMetadataService>().validateConnection(
        profile: candidate,
      );
      if (!mounted) return;
      setState(() {
        _isTestingConnection = false;
        _testConnectionSuccess = success;
        _testConnectionStatus = success
            ? (l10n?.connectionSuccessful ?? 'Connection successful!')
            : (l10n?.connectionFailed('Connection check returned false') ??
                  'Connection failed');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTestingConnection = false;
        _testConnectionSuccess = false;
        _testConnectionStatus =
            l10n?.connectionFailed(e.toString()) ?? 'Connection failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              widget.cluster == null
                  ? (l10n?.addCluster ?? 'Add Cluster')
                  : (l10n?.editCluster ?? 'Edit Cluster'),
            ),
          ),
          const SizedBox(width: 8),
          const ReadOnlySecurityBadge(),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 600,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    decoration: InputDecoration(
                      labelText: l10n?.securityProtocol ?? 'Security Protocol',
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
                if (_isTestingConnection || _testConnectionStatus != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isTestingConnection
                          ? Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest
                          : (_testConnectionSuccess == true
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.red.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isTestingConnection
                            ? Theme.of(context).colorScheme.outlineVariant
                            : (_testConnectionSuccess == true
                                  ? Colors.green
                                  : Colors.red),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (_isTestingConnection)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            _testConnectionSuccess == true
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            color: _testConnectionSuccess == true
                                ? Colors.green
                                : Colors.red,
                            size: 20,
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isTestingConnection
                                ? (l10n?.testingConnection ??
                                      'Testing Connection...')
                                : (_testConnectionStatus ?? ''),
                            style: TextStyle(
                              color: _isTestingConnection
                                  ? null
                                  : (_testConnectionSuccess == true
                                        ? Colors.green[800]
                                        : Colors.red[800]),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: _isTestingConnection ? null : _handleTestConnection,
              icon: const Icon(Icons.electrical_services),
              label: Text(l10n?.testConnection ?? 'Test Connection'),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n?.cancel ?? 'Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final profile = _buildCandidateProfile();
                      Navigator.pop(context, profile);
                    }
                  },
                  child: Text(
                    widget.cluster == null
                        ? (l10n?.add ?? 'Add')
                        : (l10n?.save ?? 'Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
