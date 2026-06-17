import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_ssl_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClusterSslForm', () {
    late TextEditingController keystoreLocationController;
    late TextEditingController keystorePasswordController;
    late TextEditingController truststoreLocationController;
    late TextEditingController truststorePasswordController;

    setUp(() {
      keystoreLocationController = TextEditingController();
      keystorePasswordController = TextEditingController();
      truststoreLocationController = TextEditingController();
      truststorePasswordController = TextEditingController();
    });

    tearDown(() {
      keystoreLocationController.dispose();
      keystorePasswordController.dispose();
      truststoreLocationController.dispose();
      truststorePasswordController.dispose();
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
              ),
            ),
          ),
        ),
      );

      expect(find.text('SSL Configuration'), findsOneWidget);
      expect(find.text('Keystore Location'), findsOneWidget);
      expect(find.text('Keystore Password'), findsOneWidget);
      expect(find.text('Truststore Location'), findsOneWidget);
      expect(find.text('Truststore Password'), findsOneWidget);
    });
  });
}
