import 'package:material_ui/material_ui.dart';

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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButtonFormField<String>(
            initialValue: mechanism,
            decoration: const InputDecoration(labelText: 'SASL Mechanism'),
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
              decoration: const InputDecoration(
                labelText: 'Kerberos Service Name',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: kerberosKeytabController,
              decoration: const InputDecoration(
                labelText: 'Kerberos Keytab Path',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: kerberosPrincipalController,
              decoration: const InputDecoration(
                labelText: 'Kerberos Principal',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: kerberosConfController,
              decoration: const InputDecoration(
                labelText: 'Kerberos Config (krb5.conf) Path',
              ),
            ),
          ),
        ] else if (mechanism == "OAUTHBEARER") ...[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: oauthbearerTokenController,
              decoration: const InputDecoration(labelText: 'OAuthBearer Token'),
            ),
          ),
        ] else if (mechanism != "AWS_MSK_IAM") ...[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
          ),
        ],
      ],
    );
  }
}
