import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/search/domain/filter_expression_ast.dart';
import 'package:kafkalyzer/src/features/search/domain/filter_field_suggestions.dart';
import 'package:kafkalyzer/src/features/search/models/topic_scan_mode.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/filter_expression_editing_controller.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/filter_expression_editor.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/topic_search_bar.dart';
import 'package:kafkalyzer/src/rust/api/filter_expr.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

FilterParseResultDto _mockParse({required String input}) {
  if (input.contains('INVALID')) {
    final idx = input.indexOf('INVALID');
    return FilterParseResultDto(
      ok: false,
      nodes: const [],
      canonical: null,
      error: FilterErrorDto(
        message: 'Unknown field',
        startUtf16: idx,
        endUtf16: idx + 7,
      ),
    );
  }
  return FilterParseResultDto(
    ok: true,
    nodes: [
      FilterNodeDto(
        kind: FilterNodeKind.cond,
        children: Uint32List(0),
        condition: const FilterConditionDto(
          fieldKind: FilterFieldKind.value,
          fieldPath: 'status',
          op: FilterOpDto.eq,
          scalar: FilterScalarDto(
            kind: FilterScalarKind.string,
            text: 'FAILED',
            intVal: null,
            floatVal: null,
            boolVal: null,
          ),
          listItems: [],
        ),
      ),
    ],
    canonical: 'value.status = "FAILED"',
    error: null,
  );
}

String _mockFormat({required List<FilterNodeDto> nodes}) {
  final ast = filterAstFromFlatDtos(nodes);
  String fmt(FilterAstNode n) => switch (n) {
    FilterAndNode(:final children) => children.map(fmt).join(' AND '),
    FilterOrNode(:final children) => '(${children.map(fmt).join(' OR ')})',
    FilterNotNode(:final child) => 'NOT ${fmt(child)}',
    FilterCondNode(:final condition) => () {
      final f = switch (condition.fieldKind) {
        FilterFieldKind.value => 'value.${condition.fieldPath}',
        FilterFieldKind.header => 'header.${condition.fieldPath}',
        FilterFieldKind.key => 'key',
        FilterFieldKind.keyPath => 'key.${condition.fieldPath}',
        FilterFieldKind.timestamp => 'timestamp',
        FilterFieldKind.offset => 'offset',
        FilterFieldKind.partition => 'partition',
      };
      final v = condition.scalar?.kind == FilterScalarKind.string
          ? '"${condition.scalar!.text}"'
          : (condition.scalar?.text ?? '');
      return '$f = $v';
    }(),
  };
  return fmt(ast);
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('6.1 FilterExpressionEditingController', () {
    test('text -> builder blocked when invalid, allowed when valid', () {
      final ctrl = FilterExpressionEditingController(
        initialText: 'INVALID = 1',
        parseFn: _mockParse,
        formatFn: _mockFormat,
      );
      expect(ctrl.isValid, isFalse);
      expect(ctrl.switchMode(FilterExpressionMode.builder), isFalse);
      expect(ctrl.mode, FilterExpressionMode.text);

      ctrl.setText('value.status = "FAILED"');
      expect(ctrl.validateNow(), isTrue);
      expect(ctrl.switchMode(FilterExpressionMode.builder), isTrue);
      expect(ctrl.mode, FilterExpressionMode.builder);
      expect(ctrl.switchMode(FilterExpressionMode.text), isTrue);
      expect(ctrl.text, 'value.status = "FAILED"');
      ctrl.dispose();
    });
  });

  group('6.2 FilterExpressionEditor', () {
    testWidgets(
      'shows error with column in text mode and supports builder mode',
      (tester) async {
        final ctrl = FilterExpressionEditingController(
          initialText: 'INVALID = 1',
          parseFn: _mockParse,
          formatFn: _mockFormat,
        );
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          _wrap(FilterExpressionEditor(controller: ctrl)),
        );
        expect(find.textContaining('Column 1: Unknown field'), findsOneWidget);

        ctrl.setText('value.status = "FAILED"');
        ctrl.validateNow();
        await tester.pump();
        expect(ctrl.switchMode(FilterExpressionMode.builder), isTrue);
        await tester.pump();
        expect(find.text('value.status = "FAILED"'), findsOneWidget);
      },
    );
  });

  group('6.3 resolveFilterFieldSuggestions', () {
    test('prefers schema, then analysis, then up to 200 messages', () async {
      final fromSchema = await resolveFilterFieldSuggestions(
        fetchSchemaFields: () async => ['order.id'],
        analysisFields: ['ignored'],
      );
      expect(fromSchema.source, FilterSuggestionSource.schema);
      expect(fromSchema.valuePaths, ['order.id']);

      final fromAnalysis = await resolveFilterFieldSuggestions(
        fetchSchemaFields: () async => [],
        analysisFields: ['user.id'],
      );
      expect(fromAnalysis.source, FilterSuggestionSource.analysis);
      expect(fromAnalysis.valuePaths, ['user.id']);

      final msgs = List.generate(
        5,
        (i) => KafkaMessage(
          topic: 't',
          partition: 0,
          offset: i,
          timestamp: 0,
          payload: '{"x":$i}',
          headers: const [KafkaHeader(key: 'x-req', value: '1')],
        ),
      );
      final fromSample = await resolveFilterFieldSuggestions(
        messages: msgs,
        collectPathsFn: ({required payload, required limit}) => ['x'],
      );
      expect(fromSample.source, FilterSuggestionSource.sample);
      expect(fromSample.valuePaths, ['x']);
      expect(fromSample.headerNames, ['x-req']);

      final empty = await resolveFilterFieldSuggestions();
      expect(empty.isEmpty, isTrue);
      expect(empty.source, isNull);
    });
  });

  group('6.4 TopicSearchBar expression chip and start gating', () {
    testWidgets('collapsed chip shows expression and invalid blocks onStart', (
      tester,
    ) async {
      var started = false;
      final exprCtrl = FilterExpressionEditingController(
        initialText: 'INVALID = 1',
        parseFn: _mockParse,
        formatFn: _mockFormat,
      );
      final quickCtrl = TextEditingController();
      final fieldCtrl = TextEditingController();
      final maxCtrl = TextEditingController(text: '200');
      final partCtrl = TextEditingController();
      final startOffCtrl = TextEditingController();
      final startTsCtrl = TextEditingController();
      final endOffCtrl = TextEditingController();
      final endTsCtrl = TextEditingController();
      addTearDown(() {
        exprCtrl.dispose();
        quickCtrl.dispose();
        fieldCtrl.dispose();
        maxCtrl.dispose();
        partCtrl.dispose();
        startOffCtrl.dispose();
        startTsCtrl.dispose();
        endOffCtrl.dispose();
        endTsCtrl.dispose();
      });

      await tester.pumpWidget(
        _wrap(
          TopicSearchBar(
            scanMode: TopicScanMode.latestN,
            onScanModeChanged: (_) {},
            quickFilterController: quickCtrl,
            fieldController: fieldCtrl,
            filterType: FilterType.contains,
            onFilterTypeChanged: (_) {},
            searchScope: SearchScope.both,
            onSearchScopeChanged: (_) {},
            limitResults: true,
            onLimitResultsChanged: (_) {},
            maxResultsController: maxCtrl,
            partitionController: partCtrl,
            fastTraceEnabled: false,
            onFastTraceEnabledChanged: (_) {},
            startStrategy: MultiSearchStartStrategy.latest,
            onStartStrategyChanged: (_) {},
            startOffsetController: startOffCtrl,
            startTimestampController: startTsCtrl,
            endStrategy: MultiSearchEndStrategy.latest,
            onEndStrategyChanged: (_) {},
            endOffsetController: endOffCtrl,
            endTimestampController: endTsCtrl,
            filterExpressionController: exprCtrl,
            onStart: () => started = true,
          ),
        ),
      );

      expect(find.byKey(const Key('filter_expression_chip')), findsOneWidget);
      await tester.tap(find.byType(TextField).first);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(started, isFalse);
    });
  });
}
