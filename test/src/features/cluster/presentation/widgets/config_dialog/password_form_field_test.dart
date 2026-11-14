import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/password_form_field.dart';
import 'package:kafkalyzer/src/services/secure_storage_service.dart';
import 'package:material_ui/material_ui.dart';

class _FakeSecureStorageService extends SecureStorageService {
  _FakeSecureStorageService({bool unavailable = false}) {
    this.unavailable.value = unavailable;
  }
}

void main() {
  group('PasswordFormField', () {
    late TextEditingController controller;

    setUp(() async {
      await getIt.reset();
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    Widget buildWidget() {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PasswordFormField(
            controller: controller,
            labelText: 'Password',
          ),
        ),
      );
    }

    testWidgets('shows lock icon when keyring is available', (tester) async {
      getIt.registerSingleton<SecureStorageService>(
        _FakeSecureStorageService(unavailable: false),
      );

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('shows warning icon with tooltip when keyring is unavailable', (
      tester,
    ) async {
      getIt.registerSingleton<SecureStorageService>(
        _FakeSecureStorageService(unavailable: true),
      );

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(
        find.byTooltip(
          'System keyring is unavailable. This password will not be persisted across restarts.',
        ),
        findsOneWidget,
      );
    });
  });
}
