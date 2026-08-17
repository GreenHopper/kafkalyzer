import 'package:material_ui/material_ui.dart';

class ClusterSslForm extends StatelessWidget {
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
            controller: truststoreLocationController,
            decoration: const InputDecoration(
              labelText: 'Truststore Location (PEM or JKS)',
            ),
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
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            "Option A: Keystore (PKCS12 / PFX)",
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            controller: keystoreLocationController,
            decoration: const InputDecoration(
              labelText: 'Keystore Location (.p12/.pfx)',
            ),
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
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            "Option B: Client Certificate & Private Key (PEM)",
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            controller: pemCertificateLocationController,
            decoration: const InputDecoration(
              labelText: 'Client Certificate PEM Location',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            controller: pemKeyLocationController,
            decoration: const InputDecoration(
              labelText: 'Client Private Key PEM Location',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            controller: pemKeyPasswordController,
            decoration: const InputDecoration(
              labelText: 'Client Private Key Password',
            ),
            obscureText: true,
          ),
        ),
      ],
    );
  }
}
