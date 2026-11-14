import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_basic_info_form.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_sasl_form.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_ssl_form.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/connection_diagnostics_panel.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/insecure_tls_badge.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/read_only_guidance_dialog.dart';
import 'package:kafkalyzer/src/rust/api/connection_diagnostics.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/connection_diagnostics_service.dart';

class ClusterConfigDialog extends StatefulWidget {
  final ClusterProfile? cluster;
  final List<String> existingNames;

  const ClusterConfigDialog({
    super.key,
    this.cluster,
    this.existingNames = const [],
  });

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
  late bool _verifyTls;
  bool _tlsVerificationTouched = false;

  bool _isTestingConnection = false;
  ConnectionDiagnosis? _diagnosis;

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
    _verifyTls = c?.tlsVerification != TlsVerification.disabled;
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
      tlsVerification: _tlsVerificationTouched
          ? (_verifyTls ? TlsVerification.enabled : TlsVerification.disabled)
          : (widget.cluster?.tlsVerification ?? TlsVerification.enabled),
    );
  }

  Future<void> _handleTestConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _diagnosis = null;
    });

    try {
      final candidate = _buildCandidateProfile();
      final diagnosis = await getIt<ConnectionDiagnosticsService>().diagnose(
        candidate,
      );
      if (!mounted) return;
      setState(() {
        _isTestingConnection = false;
        _diagnosis = diagnosis;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTestingConnection = false;
        _diagnosis = ConnectionDiagnosis(
          outcome: DiagnosisOutcome.failedStageUnknown,
          stages: const [],
          unattributed: [e.toString()],
          elapsedMs: BigInt.zero,
        );
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
          if (!_verifyTls) ...[
            const InsecureTlsBadge(compact: true),
            const SizedBox(width: 8),
          ],
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
                  existingNames: widget.existingNames,
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
                    verifyTls: _verifyTls,
                    onVerifyTlsChanged: (value) {
                      setState(() {
                        _verifyTls = value;
                        _tlsVerificationTouched = true;
                      });
                    },
                  ),
                ],
                if (_isTestingConnection) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n?.testingConnection ?? 'Testing Connection...',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_diagnosis != null) ...[
                  const SizedBox(height: 16),
                  ConnectionDiagnosticsPanel(diagnosis: _diagnosis!),
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
