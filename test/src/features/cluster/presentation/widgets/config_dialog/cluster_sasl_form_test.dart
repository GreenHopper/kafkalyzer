import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_sasl_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClusterSaslForm', () {
    late TextEditingController usernameController;
    late TextEditingController passwordController;
    late TextEditingController kerberosServiceNameController;
    late TextEditingController kerberosKeytabController;
    late TextEditingController kerberosPrincipalController;
    late TextEditingController kerberosConfController;
    late TextEditingController oauthbearerTokenController;

    setUp(() {
      usernameController = TextEditingController();
      passwordController = TextEditingController();
      kerberosServiceNameController = TextEditingController();
      kerberosKeytabController = TextEditingController();
      kerberosPrincipalController = TextEditingController();
      kerberosConfController = TextEditingController();
      oauthbearerTokenController = TextEditingController();
    });

    tearDown(() {
      usernameController.dispose();
      passwordController.dispose();
      kerberosServiceNameController.dispose();
      kerberosKeytabController.dispose();
      kerberosPrincipalController.dispose();
      kerberosConfController.dispose();
      oauthbearerTokenController.dispose();
    });

    testWidgets('renders fields and handles mechanism change', (tester) async {
      String? selectedMechanism = 'PLAIN';

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkRipple.splashFactory,
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ClusterSaslForm(
                  mechanism: selectedMechanism,
                  onMechanismChanged: (val) =>
                      setState(() => selectedMechanism = val),
                  usernameController: usernameController,
                  passwordController: passwordController,
                  kerberosServiceNameController: kerberosServiceNameController,
                  kerberosKeytabController: kerberosKeytabController,
                  kerberosPrincipalController: kerberosPrincipalController,
                  kerberosConfController: kerberosConfController,
                  oauthbearerTokenController: oauthbearerTokenController,
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('SASL Mechanism'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('PLAIN'), findsOneWidget);

      // Change mechanism
      await tester.tap(find.text('PLAIN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SCRAM-SHA-256').last);
      await tester.pumpAndSettle();

      expect(selectedMechanism, 'SCRAM-SHA-256');
      expect(find.text('SCRAM-SHA-256'), findsOneWidget);
    });
  });
}
