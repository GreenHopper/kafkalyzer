import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/file_picker_form_field.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/password_form_field.dart';

enum SslClientAuthMode {
  none,
  keystore,
  pem,
}

class ClusterSslForm extends StatefulWidget {
  final TextEditingController keystoreLocationController;
  final TextEditingController keystorePasswordController;
  final TextEditingController truststoreLocationController;
  final TextEditingController truststorePasswordController;
  final TextEditingController pemCertificateLocationController;
  final TextEditingController pemKeyLocationController;
  final TextEditingController pemKeyPasswordController;

  const ClusterSslForm({
    super.key,
    required this.keystoreLocationController,
    required this.keystorePasswordController,
    required this.truststoreLocationController,
    required this.truststorePasswordController,
    required this.pemCertificateLocationController,
    required this.pemKeyLocationController,
    required this.pemKeyPasswordController,
  });

  @override
  State<ClusterSslForm> createState() => _ClusterSslFormState();
}

class _ClusterSslFormState extends State<ClusterSslForm> {
  late SslClientAuthMode _authMode;

  @override
  void initState() {
    super.initState();
    if (widget.pemCertificateLocationController.text.isNotEmpty ||
        widget.pemKeyLocationController.text.isNotEmpty) {
      _authMode = SslClientAuthMode.pem;
    } else if (widget.keystoreLocationController.text.isNotEmpty) {
      _authMode = SslClientAuthMode.keystore;
    } else {
      _authMode = SslClientAuthMode.none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            l10n?.sslConfigurationTitle ?? "SSL Configuration",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: FilePickerFormField(
            controller: widget.truststoreLocationController,
            labelText: l10n?.truststoreLocationLabel ??
                'Truststore Location (PEM or JKS)',
            allowedExtensions: const ['pem', 'jks', 'crt', 'truststore'],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: PasswordFormField(
            controller: widget.truststorePasswordController,
            labelText:
                l10n?.truststorePasswordLabel ?? 'Truststore Password',
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Text(
            l10n?.sslClientAuthMode ?? 'Client Authentication (mTLS)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<SslClientAuthMode>(
              segments: [
                ButtonSegment<SslClientAuthMode>(
                  value: SslClientAuthMode.none,
                  label: Text(l10n?.sslClientAuthNone ?? 'None'),
                ),
                ButtonSegment<SslClientAuthMode>(
                  value: SslClientAuthMode.keystore,
                  label: Text(
                    l10n?.sslClientAuthKeystore ?? 'Keystore (PKCS12 / JKS)',
                  ),
                ),
                ButtonSegment<SslClientAuthMode>(
                  value: SslClientAuthMode.pem,
                  label: Text(l10n?.sslClientAuthPem ?? 'PEM Cert & Key'),
                ),
              ],
              selected: {_authMode},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _authMode = newSelection.first;
                });
              },
            ),
          ),
        ),
        if (_authMode == SslClientAuthMode.keystore) ...[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FilePickerFormField(
              controller: widget.keystoreLocationController,
              labelText: l10n?.keystoreLocationLabel ??
                  'Keystore Location (.p12/.pfx/.jks)',
              allowedExtensions: const ['p12', 'pfx', 'jks', 'keystore'],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: PasswordFormField(
              controller: widget.keystorePasswordController,
              labelText:
                  l10n?.keystorePasswordLabel ?? 'Keystore Password',
            ),
          ),
        ] else if (_authMode == SslClientAuthMode.pem) ...[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FilePickerFormField(
              controller: widget.pemCertificateLocationController,
              labelText: l10n?.clientCertPemLocationLabel ??
                  'Client Certificate PEM Location',
              allowedExtensions: const ['pem', 'crt', 'cer'],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FilePickerFormField(
              controller: widget.pemKeyLocationController,
              labelText: l10n?.clientKeyPemLocationLabel ??
                  'Client Private Key PEM Location',
              allowedExtensions: const ['pem', 'key'],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: PasswordFormField(
              controller: widget.pemKeyPasswordController,
              labelText: l10n?.clientKeyPasswordLabel ??
                  'Client Private Key Password',
            ),
          ),
        ],
      ],
    );
  }
}
