import 'package:flutter/material.dart';

class ClusterSaslForm extends StatelessWidget {
  final String? mechanism;
  final ValueChanged<String?> onMechanismChanged;
  final TextEditingController usernameController;
  final TextEditingController passwordController;

  const ClusterSaslForm({
    super.key,
    required this.mechanism,
    required this.onMechanismChanged,
    required this.usernameController,
    required this.passwordController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
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
            DropdownMenuItem(value: "GSSAPI", child: Text("GSSAPI")),
          ],
          onChanged: onMechanismChanged,
        ),
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
    );
  }
}
