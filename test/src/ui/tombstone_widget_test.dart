import 'package:kafkalyzer/src/ui/tombstone_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TombstoneWidget', () {
    testWidgets('renders tombstone indicator text and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TombstoneWidget())),
      );

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.text('TOMBSTONE (Value is NULL)'), findsOneWidget);
    });
  });
}
