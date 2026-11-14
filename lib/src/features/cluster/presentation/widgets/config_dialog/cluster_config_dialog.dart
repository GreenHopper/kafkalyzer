import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/client_properties_preview_dialog.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_basic_info_form.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_sasl_form.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_ssl_form.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/connection_diagnostics_panel.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/environment_tag.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/insecure_tls_badge.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/read_only_guidance_dialog.dart';
import 'package:kafkalyzer/src/rust/api/connection_diagnostics.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/profile_tools.dart';
import 'package:kafkalyzer/src/services/cluster_profile_tools.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/connection_diagnostics_service.dart';

class ClusterConfigDialog extends StatefulWidget {
  final ClusterProfile? cluster;
  final List<String> existingNames;
  final bool isDuplicate;
  final Future<({String name, Uint8List bytes})?> Function()?
  pickClientPropertiesFile;

  const ClusterConfigDialog({
    super.key,
    this.cluster,
    this.existingNames = const [],
    this.isDuplicate = false,
    this.pickClientPropertiesFile,
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
  late TextEditingController _environmentLabelController;
  late TextEditingController _extraPropertiesController;

  late String _securityProtocol;
  String? _mechanism;
  late bool _verifyTls;
  bool _tlsVerificationTouched = false;
  String? _environmentColor;
  bool _environmentColorTouched = false;
  String? _importError;

  bool _isTestingConnection = false;
  ConnectionDiagnosis? _diagnosis;

  ClusterProfileTools get _tools => getIt.isRegistered<ClusterProfileTools>()
      ? getIt<ClusterProfileTools>()
      : const ClusterProfileTools();

  bool get _isAddMode => widget.cluster == null && !widget.isDuplicate;

  @override
  void initState() {
    super.initState();
    final c = widget.cluster;
    final initialName = widget.isDuplicate && c != null
        ? suggestCopyName(c.name, widget.existingNames)
        : (c?.name ?? '');
    _nameController = TextEditingController(text: initialName);
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
    _environmentLabelController = TextEditingController(
      text: c?.environmentLabel ?? '',
    );
    _extraPropertiesController = TextEditingController(
      text: c?.extraProperties ?? '',
    );

    _securityProtocol = c?.securityProtocol ?? 'PLAINTEXT';
    _mechanism = c?.mechanism ?? 'PLAIN';
    _verifyTls = c?.tlsVerification != TlsVerification.disabled;
    _environmentColor = c?.environmentColor;
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
    _environmentLabelController.dispose();
    _extraPropertiesController.dispose();
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
      environmentLabel: _environmentLabelController.text.trim().isEmpty
          ? null
          : _environmentLabelController.text.trim(),
      environmentColor: _environmentLabelController.text.trim().isEmpty
          ? null
          : _environmentColor,
      extraProperties: _extraPropertiesController.text.trim().isEmpty
          ? null
          : _extraPropertiesController.text.trim(),
    );
  }

  String _formatExtraPropertyIssue(
    AppLocalizations? l10n,
    ExtraPropertyIssue issue,
  ) {
    final line = issue.line.toInt();
    switch (issue.kind) {
      case ExtraPropertyIssueKind.syntax:
        return l10n?.extraPropertiesSyntaxError(line) ??
            'Line $line: invalid syntax (expected key=value)';
      case ExtraPropertyIssueKind.notAllowed:
        return l10n?.extraPropertiesNotAllowed(line, issue.key) ??
            'Line $line: "${issue.key}" is not allowed';
      case ExtraPropertyIssueKind.invalidValue:
        final allowed = issue.allowed ?? '';
        return l10n?.extraPropertiesInvalidValue(line, issue.key, allowed) ??
            'Line $line: invalid value for "${issue.key}" (allowed: $allowed)';
      case ExtraPropertyIssueKind.duplicate:
        return l10n?.extraPropertiesDuplicate(line, issue.key) ??
            'Line $line: duplicate key "${issue.key}"';
    }
  }

  Future<void> _handleImportClientProperties() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _importError = null);

    try {
      Uint8List? bytes;
      if (widget.pickClientPropertiesFile != null) {
        final picked = await widget.pickClientPropertiesFile!();
        if (picked == null) return;
        bytes = picked.bytes;
      } else {
        final result = await FilePicker.pickFiles(
          type: FileType.any,
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;
        final file = result.files.single;
        if (file.bytes != null) {
          bytes = file.bytes!;
        } else if (file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }
      }
      if (bytes == null) return;
      if (bytes.length > 1024 * 1024) {
        if (!mounted) return;
        setState(() {
          _importError =
              l10n?.importClientPropertiesTooLarge ??
              'File is larger than 1 MiB and cannot be imported.';
        });
        return;
      }

      final String content;
      try {
        content = utf8.decode(bytes);
      } on FormatException {
        if (!mounted) return;
        setState(() {
          _importError =
              l10n?.importClientPropertiesInvalidUtf8 ??
              'File is not valid UTF-8 and cannot be read.';
        });
        return;
      }

      final preview = await _tools.parseClientProperties(content);
      if (!mounted) return;

      final shouldApply = await showDialog<bool>(
        context: context,
        builder: (_) => ClientPropertiesPreviewDialog(preview: preview),
      );
      if (shouldApply == true && mounted) {
        _applyClientPropertiesPreview(preview);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importError =
            l10n?.importClientPropertiesReadError(e.toString()) ??
            'Could not read file: $e';
      });
    }
  }

  void _applyClientPropertiesPreview(ClientPropertiesPreview preview) {
    final p = preview.profile;
    setState(() {
      if (p.bootstrapServers.trim().isNotEmpty) {
        _bootstrapServersController.text = p.bootstrapServers;
      }
      if (p.securityProtocol != null && p.securityProtocol!.isNotEmpty) {
        _securityProtocol = p.securityProtocol!;
      }
      if (p.mechanism != null && p.mechanism!.isNotEmpty) {
        _mechanism = p.mechanism!;
      }
      if (p.saslUsername != null && p.saslUsername!.isNotEmpty) {
        _saslUsernameController.text = p.saslUsername!;
      }
      if (p.saslPassword != null && p.saslPassword!.isNotEmpty) {
        _saslPasswordController.text = p.saslPassword!;
      }
      if (p.saslKerberosServiceName != null &&
          p.saslKerberosServiceName!.isNotEmpty) {
        _saslKerberosServiceNameController.text = p.saslKerberosServiceName!;
      }
      if (p.saslKerberosKeytab != null && p.saslKerberosKeytab!.isNotEmpty) {
        _saslKerberosKeytabController.text = p.saslKerberosKeytab!;
      }
      if (p.saslKerberosPrincipal != null &&
          p.saslKerberosPrincipal!.isNotEmpty) {
        _saslKerberosPrincipalController.text = p.saslKerberosPrincipal!;
      }
      if (p.sslTruststoreLocation != null &&
          p.sslTruststoreLocation!.isNotEmpty) {
        _sslTruststoreLocationController.text = p.sslTruststoreLocation!;
      }
      if (p.sslTruststorePassword != null &&
          p.sslTruststorePassword!.isNotEmpty) {
        _sslTruststorePasswordController.text = p.sslTruststorePassword!;
      }
      if (p.sslKeystoreLocation != null && p.sslKeystoreLocation!.isNotEmpty) {
        _sslKeystoreLocationController.text = p.sslKeystoreLocation!;
      }
      if (p.sslKeystorePassword != null && p.sslKeystorePassword!.isNotEmpty) {
        _sslKeystorePasswordController.text = p.sslKeystorePassword!;
      }
      if (p.sslPemCertificateLocation != null &&
          p.sslPemCertificateLocation!.isNotEmpty) {
        _sslPemCertificateLocationController.text =
            p.sslPemCertificateLocation!;
      }
      if (p.sslPemKeyLocation != null && p.sslPemKeyLocation!.isNotEmpty) {
        _sslPemKeyLocationController.text = p.sslPemKeyLocation!;
      }
      if (p.sslPemKeyPassword != null && p.sslPemKeyPassword!.isNotEmpty) {
        _sslPemKeyPasswordController.text = p.sslPemKeyPassword!;
      }
      if (p.schemaRegistryUrl != null && p.schemaRegistryUrl!.isNotEmpty) {
        _schemaRegistryUrlController.text = p.schemaRegistryUrl!;
      }
      if (p.schemaRegistryUsername != null &&
          p.schemaRegistryUsername!.isNotEmpty) {
        _schemaRegistryUsernameController.text = p.schemaRegistryUsername!;
      }
      if (p.schemaRegistryPassword != null &&
          p.schemaRegistryPassword!.isNotEmpty) {
        _schemaRegistryPasswordController.text = p.schemaRegistryPassword!;
      }
      final extras = preview.extraProperties.trim();
      if (extras.isNotEmpty) {
        final existing = _extraPropertiesController.text.trim();
        _extraPropertiesController.text = existing.isEmpty
            ? extras
            : '$existing\n$extras';
      }
    });
  }

  Widget _buildEnvironmentTagSection(AppLocalizations? l10n) {
    const suggestions = ['DEV', 'TEST', 'STAGE', 'PROD'];

    void maybePreselectColor(String label) {
      if (_environmentColorTouched) return;
      final suggested = EnvironmentPalette.suggestedColorForLabel(label);
      if (suggested != null && suggested != _environmentColor) {
        setState(() => _environmentColor = suggested);
      }
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.environmentTagSectionTitle ?? 'Environment Tag (optional)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Autocomplete<String>(
            initialValue: _environmentLabelController.value,
            optionsBuilder: (textEditingValue) {
              final query = textEditingValue.text.trim().toUpperCase();
              if (query.isEmpty) return suggestions;
              return suggestions.where((s) => s.contains(query));
            },
            onSelected: (selection) {
              _environmentLabelController.text = selection;
              maybePreselectColor(selection);
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              if (controller.text != _environmentLabelController.text) {
                controller.text = _environmentLabelController.text;
              }
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: l10n?.environmentLabelField ?? 'Environment Label',
                  hintText:
                      l10n?.environmentLabelHint ??
                      'e.g. DEV, TEST, STAGE, PROD',
                ),
                onChanged: (val) {
                  _environmentLabelController.text = val;
                  maybePreselectColor(val);
                },
                validator: (val) {
                  final trimmed = val?.trim() ?? '';
                  if (trimmed.length > 16) {
                    return l10n?.environmentLabelTooLong(16) ??
                        'Environment label must be at most 16 characters';
                  }
                  return null;
                },
              );
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final key in EnvironmentPalette.keys)
                Builder(
                  builder: (context) {
                    final colors = EnvironmentPalette.resolve(context, key);
                    final isSelected = _environmentColor == key;
                    final label = l10n != null
                        ? EnvironmentPalette.localizedName(l10n, key)
                        : key;
                    return ChoiceChip(
                      selected: isSelected,
                      avatar: CircleAvatar(
                        backgroundColor: colors.container,
                        radius: 8,
                      ),
                      label: Text(label),
                      onSelected: (selected) {
                        setState(() {
                          _environmentColorTouched = true;
                          _environmentColor = selected ? key : null;
                        });
                      },
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExtraPropertiesSection(AppLocalizations? l10n) {
    final initiallyExpanded = _extraPropertiesController.text.trim().isNotEmpty;
    final allowed = _tools.allowedExtraProperties();

    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      title: Text(l10n?.extraPropertiesTitle ?? 'Additional client properties'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: TextFormField(
            controller: _extraPropertiesController,
            maxLines: 5,
            minLines: 2,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              hintText: l10n?.extraPropertiesHint ?? 'One key=value per line',
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              final issues = _tools.validateExtraProperties(value ?? '');
              if (issues.isNotEmpty) {
                return _formatExtraPropertyIssue(l10n, issues.first);
              }
              return null;
            },
          ),
        ),
        if (allowed.isNotEmpty)
          ExpansionTile(
            dense: true,
            title: Text(
              l10n?.extraPropertiesAllowedKeysTitle ?? 'Allowed keys',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final prop in allowed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          '${prop.key}: ${prop.valueHint}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
      ],
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
              widget.isDuplicate
                  ? (l10n?.duplicateClusterTitle ?? 'Duplicate Cluster')
                  : (widget.cluster == null
                        ? (l10n?.addCluster ?? 'Add Cluster')
                        : (l10n?.editCluster ?? 'Edit Cluster')),
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
                if (_isAddMode) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _handleImportClientProperties,
                      icon: const Icon(Icons.file_upload_outlined, size: 18),
                      label: Text(
                        l10n?.importClientPropertiesAction ??
                            'Import client.properties',
                      ),
                    ),
                  ),
                  if (_importError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _importError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                ],
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
                _buildEnvironmentTagSection(l10n),
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
                _buildExtraPropertiesSection(l10n),
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
                    widget.cluster == null || widget.isDuplicate
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
