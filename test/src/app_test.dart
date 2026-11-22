import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/app.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('KafkalyzerApp builds MaterialApp.router with theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const KafkalyzerApp());
    // First frame is enough to cover build; MainLayout may still be settling.
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
