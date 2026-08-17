import 'package:kafkalyzer/src/ui/date_format_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  group('DateFormatUtils', () {
    testWidgets('formatDateTime formats correctly for US locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en', 'US')],
          locale: const Locale('en', 'US'),
          home: Builder(
            builder: (context) {
              final date = DateTime(2023, 10, 25, 14, 30, 0);
              final formatted = DateFormatUtils.formatDateTime(context, date);
              // US format: M/d/y H:mm:ss -> 10/25/2023 14:30:00
              // Note: add_Hms adds 24h format usually but depends on skeleton.
              // Actually for en_US it might be h:mm:ss a or H:mm:ss.
              // Let's verify what it produces exactly or check parts.
              return Text(formatted);
            },
          ),
        ),
      );
      final textFinder = find.byType(Text);
      expect(textFinder, findsOneWidget);
      final text = tester.widget<Text>(textFinder).data!;
      expect(text, contains('10/25/2023'));
      expect(text, contains('14:30:00'));
    });

    testWidgets('formatDateTime includes milliseconds when requested', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en', 'US')],
          locale: const Locale('en', 'US'),
          home: Builder(
            builder: (context) {
              final date = DateTime(2023, 10, 25, 14, 30, 0, 123);
              final formatted = DateFormatUtils.formatDateTime(
                context,
                date,
                withMilliseconds: true,
              );
              return Text(formatted);
            },
          ),
        ),
      );
      final text = tester.widget<Text>(find.byType(Text)).data!;
      expect(text, endsWith('.123'));
    });

    testWidgets('parseDateTime parses correctly', (tester) async {
      DateTime? parsed;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en', 'US')],
          locale: const Locale('en', 'US'),
          home: Builder(
            builder: (context) {
              parsed = DateFormatUtils.parseDateTime(
                context,
                '10/25/2023 14:30:00',
              );
              return Container();
            },
          ),
        ),
      );
      expect(parsed, isNotNull);
      expect(parsed!.year, 2023);
      expect(parsed!.month, 10);
      expect(parsed!.day, 25);
      expect(parsed!.hour, 14);
      expect(parsed!.minute, 30);
    });

    testWidgets('formatDate, formatTime and formatFromNow work correctly', (
      tester,
    ) async {
      String? formattedDate;
      String? formattedTime;
      String? formattedFromNow;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en', 'US')],
          locale: const Locale('en', 'US'),
          home: Builder(
            builder: (context) {
              final date = DateTime(2023, 10, 25, 14, 30, 0);
              formattedDate = DateFormatUtils.formatDate(context, date);
              formattedTime = DateFormatUtils.formatTime(context, date);
              formattedFromNow = DateFormatUtils.formatFromNow(
                context,
                const Duration(hours: 1),
              );
              return Container();
            },
          ),
        ),
      );

      expect(formattedDate, '10/25/2023');
      expect(formattedTime, '14:30:00');
      expect(formattedFromNow, isNotEmpty);
    });

    testWidgets('parseDateTime handles edge cases and failures', (
      tester,
    ) async {
      DateTime? parsedEmpty;
      DateTime? parsedLoose;
      DateTime? parsedFailed;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en', 'US')],
          locale: const Locale('en', 'US'),
          home: Builder(
            builder: (context) {
              parsedEmpty = DateFormatUtils.parseDateTime(context, '');
              parsedLoose = DateFormatUtils.parseDateTime(
                context,
                '10/25/2023  14:30:00',
              );
              parsedFailed = DateFormatUtils.parseDateTime(
                context,
                'not-a-date',
              );
              return Container();
            },
          ),
        ),
      );

      expect(parsedEmpty, isNull);
      expect(parsedLoose, isNotNull); // parseLoose succeeds
      expect(parsedFailed, isNull);
    });
  });
}
