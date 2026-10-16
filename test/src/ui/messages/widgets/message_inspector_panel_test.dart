import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/topic_schema_inspector_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/message_inspector_panel.dart';
import 'package:mockito/mockito.dart';
import '../../../features/schema/presentation/widgets/schema_viewer_dialog_test.mocks.dart';

void main() {
  late MockSchemaController mockSchemaController;

  final testProfile = ClusterProfile(
    name: 'test-cluster',
    bootstrapServers: 'localhost:9092',
    schemaRegistryUrl: 'http://localhost:8081',
    securityProtocol: 'plaintext',
    mechanism: 'plain',
  );

  setUp(() {
    mockSchemaController = MockSchemaController();
    if (getIt.isRegistered<SchemaController>()) {
      getIt.unregister<SchemaController>();
    }
    getIt.registerSingleton<SchemaController>(mockSchemaController);
  });

  tearDown(() {
    if (getIt.isRegistered<SchemaController>()) {
      getIt.unregister<SchemaController>();
    }
  });

  final testMessage = KafkaMessage(
    topic: 'test-orders',
    partition: 2,
    offset: 1042,
    timestamp: 1695888000000,
    key: 'order-1234',
    payload: '{"orderId":"1234","status":"CONFIRMED"}',
    headers: [
      KafkaHeader(key: 'trace-id', value: 'abc-xyz-123'),
      KafkaHeader(key: 'app-version', value: '2.4.0'),
    ],
  );

  Widget createWidgetUnderTest({
    required KafkaMessage message,
    InspectorDockPosition dockPosition = InspectorDockPosition.bottom,
    VoidCallback? onToggleDockPosition,
    VoidCallback? onClose,
    String? searchPhrase,
    ClusterProfile? profile,
    ValueChanged<String>? onPinToColumn,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: MessageInspectorPanel(
          message: message,
          dockPosition: dockPosition,
          onToggleDockPosition: onToggleDockPosition ?? () {},
          onClose: onClose ?? () {},
          searchPhrase: searchPhrase,
          profile: profile,
          onPinToColumn: onPinToColumn,
        ),
      ),
    );
  }

  testWidgets('renders metadata chips correctly', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest(message: testMessage));
    await tester.pumpAndSettle();

    expect(find.textContaining('order-1234'), findsOneWidget);
    expect(find.text('P: 2'), findsOneWidget);
    expect(find.text('O: 1042'), findsOneWidget);
    // Header count badge on Key & Headers tab
    expect(find.text('2'), findsWidgets);
  });

  testWidgets(
    'renders tabs and allows switching to Key & Headers and Raw tabs',
    (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(message: testMessage));
      await tester.pumpAndSettle();

      // Default tab is Payload
      expect(
        find.text('order-1234'),
        findsNothing,
      ); // key is on key & headers tab

      // Switch to Key & Headers tab
      await tester.tap(find.text('Key & Headers'));
      await tester.pumpAndSettle();

      expect(find.text('order-1234'), findsOneWidget);
      expect(find.text('trace-id'), findsOneWidget);
      expect(find.text('abc-xyz-123'), findsOneWidget);
      expect(find.text('app-version'), findsOneWidget);
      expect(find.text('2.4.0'), findsOneWidget);

      // Switch to Raw JSON tab
      await tester.tap(find.text('Raw JSON'));
      await tester.pumpAndSettle();

      expect(find.textContaining('CONFIRMED'), findsOneWidget);
    },
  );

  testWidgets(
    'triggers onToggleDockPosition callback when dock button is clicked',
    (tester) async {
      bool toggled = false;
      await tester.pumpWidget(
        createWidgetUnderTest(
          message: testMessage,
          dockPosition: InspectorDockPosition.bottom,
          onToggleDockPosition: () => toggled = true,
        ),
      );
      await tester.pumpAndSettle();

      final dockButton = find.byTooltip('Dock to right');
      expect(dockButton, findsOneWidget);

      await tester.tap(dockButton);
      await tester.pumpAndSettle();

      expect(toggled, isTrue);
    },
  );

  testWidgets('triggers onClose callback when close button is clicked', (
    tester,
  ) async {
    bool closed = false;
    await tester.pumpWidget(
      createWidgetUnderTest(message: testMessage, onClose: () => closed = true),
    );
    await tester.pumpAndSettle();

    final closeButton = find.byTooltip('Close inspector');
    expect(closeButton, findsOneWidget);

    await tester.tap(closeButton);
    await tester.pumpAndSettle();

    expect(closed, isTrue);
  });

  testWidgets(
    'renders Copy message button in the top bar and copies to clipboard',
    (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(message: testMessage));
      await tester.pumpAndSettle();

      final copyButton = find.byTooltip('Copy message');
      expect(copyButton, findsOneWidget);

      await tester.tap(copyButton);
      await tester.pumpAndSettle();

      expect(find.text('Full message copied to clipboard'), findsOneWidget);
    },
  );

  testWidgets(
    'aligns action buttons at the far right and metadata in the center of header',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest(message: testMessage));
      await tester.pumpAndSettle();

      final closeButton = find.byTooltip('Close inspector');
      final closeCenter = tester.getCenter(closeButton);
      // Close button should be at the far right end
      expect(closeCenter.dx, greaterThan(1150));

      final pCenter = tester.getCenter(find.text('P: 2'));
      final copyCenter = tester.getCenter(find.byTooltip('Copy metadata'));
      final metadataMidpoint = (pCenter.dx + copyCenter.dx) / 2;
      // Midpoint of metadata section should be dead center (around 600 in a 1200-wide viewport)
      expect(metadataMidpoint, closeTo(600, 20));
    },
  );

  testWidgets(
    'renders embedded TopicSchemaInspectorView when Schema tab is tapped',
    (tester) async {
      when(
        mockSchemaController.getSchemas(any),
      ).thenReturn(['test-orders-value']);
      when(mockSchemaController.fetchSchemas(any)).thenAnswer((_) async {});
      when(mockSchemaController.fetchSchemaContent(any, any)).thenAnswer(
        (_) async =>
            '{"type": "record", "name": "Order", "fields": [{"name": "orderId", "type": "string"}]}',
      );

      await tester.pumpWidget(
        createWidgetUnderTest(message: testMessage, profile: testProfile),
      );
      await tester.pumpAndSettle();

      final schemaTab = find.text('Schema');
      expect(schemaTab, findsOneWidget);

      await tester.tap(schemaTab);
      await tester.pumpAndSettle();

      expect(find.byType(TopicSchemaInspectorView), findsOneWidget);
    },
  );

  testWidgets('passes onPinToColumn callback to TopicSchemaInspectorView', (
    tester,
  ) async {
    String? pinnedColumn;
    when(
      mockSchemaController.getSchemas(any),
    ).thenReturn(['test-orders-value']);
    when(mockSchemaController.fetchSchemas(any)).thenAnswer((_) async {});
    when(mockSchemaController.fetchSchemaContent(any, any)).thenAnswer(
      (_) async =>
          '{"type": "record", "name": "Order", "fields": [{"name": "orderId", "type": "string"}]}',
    );

    await tester.pumpWidget(
      createWidgetUnderTest(
        message: testMessage,
        profile: testProfile,
        onPinToColumn: (col) => pinnedColumn = col,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Schema'));
    await tester.pumpAndSettle();

    final inspectorFinder = find.byType(TopicSchemaInspectorView);
    expect(inspectorFinder, findsOneWidget);

    final TopicSchemaInspectorView inspector = tester.widget(inspectorFinder);
    expect(inspector.onPinToColumn, isNotNull);

    inspector.onPinToColumn!('orderId');
    expect(pinnedColumn, 'orderId');
  });
}
