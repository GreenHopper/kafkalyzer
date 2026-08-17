import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_basic_info_form.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClusterBasicInfoForm', () {
    late TextEditingController nameController;
    late TextEditingController bootstrapServersController;
    late TextEditingController schemaRegistryUrlController;
    late TextEditingController schemaRegistryUsernameController;
    late TextEditingController schemaRegistryPasswordController;

    setUp(() {
      nameController = TextEditingController();
      bootstrapServersController = TextEditingController();
      schemaRegistryUrlController = TextEditingController();
      schemaRegistryUsernameController = TextEditingController();
      schemaRegistryPasswordController = TextEditingController();
    });

    tearDown(() {
      nameController.dispose();
      bootstrapServersController.dispose();
      schemaRegistryUrlController.dispose();
      schemaRegistryUsernameController.dispose();
      schemaRegistryPasswordController.dispose();
    });

    testWidgets('renders all fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClusterBasicInfoForm(
              nameController: nameController,
              bootstrapServersController: bootstrapServersController,
              schemaRegistryUrlController: schemaRegistryUrlController,
              schemaRegistryUsernameController:
                  schemaRegistryUsernameController,
              schemaRegistryPasswordController:
                  schemaRegistryPasswordController,
            ),
          ),
        ),
      );

      expect(find.text('Cluster Name'), findsOneWidget);
      expect(
        find.text('Bootstrap Servers (e.g. localhost:9092)'),
        findsOneWidget,
      );
      expect(find.text('Schema Registry URL (Optional)'), findsOneWidget);
    });

    testWidgets('validates schema registry URL', (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: ClusterBasicInfoForm(
                nameController: nameController,
                bootstrapServersController: bootstrapServersController,
                schemaRegistryUrlController: schemaRegistryUrlController,
                schemaRegistryUsernameController:
                    schemaRegistryUsernameController,
                schemaRegistryPasswordController:
                    schemaRegistryPasswordController,
              ),
            ),
          ),
        ),
      );

      // Invalid: missing protocol
      await tester.enterText(
        find.ancestor(
          of: find.text('Schema Registry URL (Optional)'),
          matching: find.byType(TextFormField),
        ),
        'localhost:8081',
      );
      await tester.pump();
      formKey.currentState!.validate();
      await tester.pump();
      expect(
        find.text('Missing protocol (http:// or https://)'),
        findsOneWidget,
      );

      // Warning: likely typo (dot instead of colon)
      await tester.enterText(
        find.ancestor(
          of: find.text('Schema Registry URL (Optional)'),
          matching: find.byType(TextFormField),
        ),
        'http://localhost.8081',
      );
      await tester.pump();
      formKey.currentState!.validate();
      await tester.pump();
      expect(
        find.text("Likely typo: use ':' for port instead of '.'"),
        findsOneWidget,
      );

      // Valid
      await tester.enterText(
        find.ancestor(
          of: find.text('Schema Registry URL (Optional)'),
          matching: find.byType(TextFormField),
        ),
        'http://localhost:8081',
      );
      await tester.pump();
      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('Missing protocol (http:// or https://)'), findsNothing);
      expect(
        find.text("Likely typo: use ':' for port instead of '.'"),
        findsNothing,
      );
    });
  });
}
