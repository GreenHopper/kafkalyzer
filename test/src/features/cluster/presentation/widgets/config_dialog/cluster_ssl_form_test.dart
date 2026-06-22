import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_ssl_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClusterSslForm', () {
    late TextEditingController keystoreLocationController;
    late TextEditingController keystorePasswordController;
    late TextEditingController truststoreLocationController;
    late TextEditingController truststorePasswordController;
    late TextEditingController pemCertificateLocationController;
    late TextEditingController pemKeyLocationController;
    late TextEditingController pemKeyPasswordController;

    setUp(() {
      keystoreLocationController = TextEditingController();
      keystorePasswordController = TextEditingController();
      truststoreLocationController = TextEditingController();
      truststorePasswordController = TextEditingController();
      pemCertificateLocationController = TextEditingController();
      pemKeyLocationController = TextEditingController();
      pemKeyPasswordController = TextEditingController();
    });

    tearDown(() {
      keystoreLocationController.dispose();
      keystorePasswordController.dispose();
      truststoreLocationController.dispose();
      truststorePasswordController.dispose();
      pemCertificateLocationController.dispose();
      pemKeyLocationController.dispose();
      pemKeyPasswordController.dispose();
    });

    testWidgets('renders all SSL fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClusterSslForm(
                keystoreLocationController: keystoreLocationController,
                keystorePasswordController: keystorePasswordController,
                truststoreLocationController: truststoreLocationController,
                truststorePasswordController: truststorePasswordController,
                pemCertificateLocationController:
                    pemCertificateLocationController,
                pemKeyLocationController: pemKeyLocationController,
                pemKeyPasswordController: pemKeyPasswordController,
              ),
            ),
          ),
        ),
      );

      expect(find.text('SSL Configuration'), findsOneWidget);
      expect(find.text('Keystore Location (.p12/.pfx)'), findsOneWidget);
      expect(find.text('Keystore Password'), findsOneWidget);
      expect(find.text('Truststore Location (PEM or JKS)'), findsOneWidget);
      expect(find.text('Truststore Password'), findsOneWidget);
      expect(find.text('Client Certificate PEM Location'), findsOneWidget);
      expect(find.text('Client Private Key PEM Location'), findsOneWidget);
      expect(find.text('Client Private Key Password'), findsOneWidget);
    });
  });
}
