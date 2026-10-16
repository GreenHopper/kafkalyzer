import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/file_picker_form_field.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/password_form_field.dart';

class ClusterSaslForm extends StatelessWidget {
  final String? mechanism;
  final ValueChanged<String?> onMechanismChanged;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController kerberosServiceNameController;
  final TextEditingController kerberosKeytabController;
  final TextEditingController kerberosPrincipalController;
  final TextEditingController kerberosConfController;
  final TextEditingController oauthbearerTokenController;

  const ClusterSaslForm({
    super.key,
    required this.mechanism,
    required this.onMechanismChanged,
    required this.usernameController,
    required this.passwordController,
    required this.kerberosServiceNameController,
    required this.kerberosKeytabController,
    required this.kerberosPrincipalController,
    required this.kerberosConfController,
    required this.oauthbearerTokenController,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButtonFormField<String>(
            initialValue: mechanism,
            decoration: InputDecoration(
              labelText: l10n?.saslMechanismLabel ?? 'SASL Mechanism',
            ),
            items: const [
              DropdownMenuItem(value: "PLAIN", child: Text("PLAIN")),
              DropdownMenuItem(
                value: "SCRAM-SHA-256",
                child: Text("SCRAM-SHA-256"),
              ),
              DropdownMenuItem(
                value: "SCRAM-SHA-512",
                child: Text("SCRAM-SHA-512"),
              ),
              DropdownMenuItem(
                value: "GSSAPI",
                child: Text("GSSAPI (Kerberos)"),
              ),
              DropdownMenuItem(
                value: "OAUTHBEARER",
                child: Text("OAUTHBEARER"),
              ),
              DropdownMenuItem(
                value: "AWS_MSK_IAM",
                child: Text("AWS_MSK_IAM"),
              ),
            ],
            onChanged: onMechanismChanged,
          ),
        ),
        if (mechanism == "GSSAPI") ...[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: kerberosServiceNameController,
              decoration: InputDecoration(
                labelText:
                    l10n?.kerberosServiceNameLabel ?? 'Kerberos Service Name',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FilePickerFormField(
              controller: kerberosKeytabController,
              labelText:
                  l10n?.kerberosKeytabPathLabel ?? 'Kerberos Keytab Path',
              allowedExtensions: const ['keytab'],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: kerberosPrincipalController,
              decoration: InputDecoration(
                labelText: l10n?.kerberosPrincipalLabel ?? 'Kerberos Principal',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FilePickerFormField(
              controller: kerberosConfController,
              labelText:
                  l10n?.kerberosConfigPathLabel ??
                  'Kerberos Config (krb5.conf) Path',
              allowedExtensions: const ['conf'],
            ),
          ),
        ] else if (mechanism == "OAUTHBEARER") ...[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: PasswordFormField(
              controller: oauthbearerTokenController,
              labelText: l10n?.oauthbearerTokenLabel ?? 'OAuthBearer Token',
            ),
          ),
        ] else if (mechanism != "AWS_MSK_IAM") ...[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: usernameController,
              decoration: InputDecoration(
                labelText: l10n?.saslUsernameLabel ?? 'Username',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: PasswordFormField(
              controller: passwordController,
              labelText: l10n?.saslPasswordLabel ?? 'Password',
            ),
          ),
        ],
      ],
    );
  }
}
