import 'package:flutter/material.dart';

class ClusterSslForm extends StatelessWidget {
  final TextEditingController keystoreLocationController;
  final TextEditingController keystorePasswordController;
  final TextEditingController truststoreLocationController;
  final TextEditingController truststorePasswordController;

  const ClusterSslForm({
    super.key,
    required this.keystoreLocationController,
    required this.keystorePasswordController,
    required this.truststoreLocationController,
    required this.truststorePasswordController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            "SSL Configuration",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            controller: keystoreLocationController,
            decoration: const InputDecoration(labelText: 'Keystore Location'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            controller: keystorePasswordController,
            decoration: const InputDecoration(labelText: 'Keystore Password'),
            obscureText: true,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            controller: truststoreLocationController,
            decoration: const InputDecoration(labelText: 'Truststore Location'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            controller: truststorePasswordController,
            decoration: const InputDecoration(labelText: 'Truststore Password'),
            obscureText: true,
          ),
        ),
      ],
    );
  }
}
