import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/profile_tools.dart';

/// Displays the parsed fields, additional properties, and skipped keys from
/// a `client.properties` file before the user decides to apply them.
class ClientPropertiesPreviewDialog extends StatelessWidget {
  const ClientPropertiesPreviewDialog({super.key, required this.preview});

  final ClientPropertiesPreview preview;

  static const _secretMask = '••••';

  List<(String, String)> _mappedFieldRows(AppLocalizations l10n) {
    final p = preview.profile;
    final rows = <(String, String)>[];
    if (p.bootstrapServers.trim().isNotEmpty) {
      rows.add((l10n.bootstrapServersLabel, p.bootstrapServers));
    }
    if (p.securityProtocol != null && p.securityProtocol!.isNotEmpty) {
      rows.add((l10n.securityProtocol, p.securityProtocol!));
    }
    if (p.mechanism != null && p.mechanism!.isNotEmpty) {
      rows.add((l10n.saslMechanismLabel, p.mechanism!));
    }
    if (p.saslUsername != null && p.saslUsername!.isNotEmpty) {
      rows.add((l10n.saslUsernameLabel, p.saslUsername!));
    }
    if (p.saslPassword != null && p.saslPassword!.isNotEmpty) {
      rows.add((l10n.saslPasswordLabel, _secretMask));
    }
    if (p.saslKerberosServiceName != null &&
        p.saslKerberosServiceName!.isNotEmpty) {
      rows.add((l10n.kerberosServiceNameLabel, p.saslKerberosServiceName!));
    }
    if (p.saslKerberosKeytab != null && p.saslKerberosKeytab!.isNotEmpty) {
      rows.add((l10n.kerberosKeytabPathLabel, p.saslKerberosKeytab!));
    }
    if (p.saslKerberosPrincipal != null &&
        p.saslKerberosPrincipal!.isNotEmpty) {
      rows.add((l10n.kerberosPrincipalLabel, p.saslKerberosPrincipal!));
    }
    if (p.sslTruststoreLocation != null &&
        p.sslTruststoreLocation!.isNotEmpty) {
      rows.add((l10n.truststoreLocationLabel, p.sslTruststoreLocation!));
    }
    if (p.sslTruststorePassword != null &&
        p.sslTruststorePassword!.isNotEmpty) {
      rows.add((l10n.truststorePasswordLabel, _secretMask));
    }
    if (p.sslKeystoreLocation != null && p.sslKeystoreLocation!.isNotEmpty) {
      rows.add((l10n.keystoreLocationLabel, p.sslKeystoreLocation!));
    }
    if (p.sslKeystorePassword != null && p.sslKeystorePassword!.isNotEmpty) {
      rows.add((l10n.keystorePasswordLabel, _secretMask));
    }
    if (p.sslPemCertificateLocation != null &&
        p.sslPemCertificateLocation!.isNotEmpty) {
      rows.add((l10n.clientCertPemLocationLabel, p.sslPemCertificateLocation!));
    }
    if (p.sslPemKeyLocation != null && p.sslPemKeyLocation!.isNotEmpty) {
      rows.add((l10n.clientKeyPemLocationLabel, p.sslPemKeyLocation!));
    }
    if (p.sslPemKeyPassword != null && p.sslPemKeyPassword!.isNotEmpty) {
      rows.add((l10n.clientKeyPasswordLabel, _secretMask));
    }
    if (p.schemaRegistryUrl != null && p.schemaRegistryUrl!.isNotEmpty) {
      rows.add((l10n.schemaRegistryUrlLabel, p.schemaRegistryUrl!));
    }
    if (p.schemaRegistryUsername != null &&
        p.schemaRegistryUsername!.isNotEmpty) {
      rows.add((
        l10n.schemaRegistryUsernameOptional,
        p.schemaRegistryUsername!,
      ));
    }
    if (p.schemaRegistryPassword != null &&
        p.schemaRegistryPassword!.isNotEmpty) {
      rows.add((l10n.schemaRegistryPasswordOptional, _secretMask));
    }
    return rows;
  }

  String _reasonLabel(AppLocalizations l10n, ClientPropertySkipReason reason) {
    switch (reason) {
      case ClientPropertySkipReason.notAllowed:
        return l10n.skipReasonNotAllowed;
      case ClientPropertySkipReason.unsupported:
        return l10n.skipReasonUnsupported;
      case ClientPropertySkipReason.placeholder:
        return l10n.skipReasonPlaceholder;
      case ClientPropertySkipReason.verificationOverride:
        return l10n.skipReasonVerificationOverride;
      case ClientPropertySkipReason.invalidValue:
        return l10n.skipReasonInvalidValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mapped = _mappedFieldRows(l10n);
    final hasExtras = preview.extraProperties.trim().isNotEmpty;
    final hasSkipped = preview.skipped.isNotEmpty;
    final canApply = mapped.isNotEmpty || hasExtras;

    return AlertDialog(
      title: Text(l10n.importClientPropertiesPreviewTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!canApply && !hasSkipped)
                Text(l10n.importClientPropertiesNothingToApply),
              if (mapped.isNotEmpty) ...[
                Text(
                  l10n.importClientPropertiesMappedSection,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                for (final (label, value) in mapped)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 190,
                          child: Text(
                            label,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Expanded(
                          child: SelectableText(
                            value,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              if (hasExtras) ...[
                Text(
                  l10n.importClientPropertiesExtrasSection,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SelectableText(
                    preview.extraProperties,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (hasSkipped) ...[
                Text(
                  l10n.importClientPropertiesSkippedSection,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                for (final item in preview.skipped)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            item.key,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: Text(
                            _reasonLabel(l10n, item.reason),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: canApply ? () => Navigator.pop(context, true) : null,
          child: Text(l10n.importClientPropertiesApplyAction),
        ),
      ],
    );
  }
}
