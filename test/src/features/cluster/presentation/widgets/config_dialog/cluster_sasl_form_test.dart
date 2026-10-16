import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_sasl_form.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

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

    testWidgets('renders German localized labels across SASL mechanisms', (
      tester,
    ) async {
      String? selectedMechanism = 'PLAIN';

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('de'),
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
      await tester.pumpAndSettle();

      expect(find.text('SASL-Mechanismus'), findsOneWidget);
      expect(find.text('SASL-Benutzername'), findsOneWidget);
      expect(find.text('SASL-Passwort'), findsOneWidget);

      // Switch to GSSAPI
      await tester.tap(find.text('PLAIN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GSSAPI (Kerberos)').last);
      await tester.pumpAndSettle();

      expect(find.text('Kerberos Service-Name'), findsOneWidget);
      expect(find.text('Kerberos Keytab-Pfad'), findsOneWidget);
      expect(find.text('Kerberos Principal'), findsOneWidget);
      expect(
        find.text('Kerberos Konfiguration (krb5.conf) Pfad'),
        findsOneWidget,
      );

      // Switch to OAUTHBEARER
      await tester.tap(find.text('GSSAPI (Kerberos)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OAUTHBEARER').last);
      await tester.pumpAndSettle();

      expect(find.text('OAuthbearer Token'), findsOneWidget);
    });
  });
}
