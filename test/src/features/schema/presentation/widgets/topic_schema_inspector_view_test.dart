import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/topic_schema_inspector_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/schema_registry_service.dart';
import 'package:material_ui/material_ui.dart';

class _FailingSchemaRegistryService extends SchemaRegistryService {
  @override
  Future<List<String>> fetchSubjects({required ClusterProfile profile}) async {
    throw StateError('Registry unreachable');
  }
}

void main() {
  testWidgets(
    'TopicSchemaInspectorView shows error state when fetchSchemas fails',
    (tester) async {
      final controller = SchemaController(
        registryService: _FailingSchemaRegistryService(),
      );
      const profile = ClusterProfile(
        name: 'prod',
        bootstrapServers: 'b:9092',
        schemaRegistryUrl: 'https://sr.internal:8081',
        tlsVerification: TlsVerification.enabled,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TopicSchemaInspectorView(
              profile: profile,
              topicName: 'orders',
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('Registry unreachable'), findsOneWidget);
    },
  );
}
