import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/consumer/presentation/group_details_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const testProfile = ClusterProfile(
    name: 'test-cluster',
    bootstrapServers: 'localhost:9092',
  );

  ConsumerGroupMember member(
    String id, {
    List<TopicPartition> assignments = const [],
    bool decodable = true,
  }) => ConsumerGroupMember(
    memberId: id,
    clientId: '$id-client',
    clientHost: '10.0.0.7',
    subscriptions: const ['orders'],
    assignments: assignments,
    assignmentDecodable: decodable,
  );

  ConsumerGroupLag group({
    List<ConsumerGroupMember> members = const [],
    List<TopicPartition> unassigned = const [],
  }) => ConsumerGroupLag(
    groupId: 'orders-consumers',
    state: 'Stable',
    protocolType: 'consumer',
    partitionLags: const [],
    membersCount: members.length,
    topicsCount: 1,
    members: members,
    unassignedPartitions: unassigned,
  );

  Widget createWidgetUnderTest(ConsumerGroupLag groupLag) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 1200,
          height: 900,
          child: SingleChildScrollView(
            child: Builder(
              builder: (context) => GroupDetailsView(
                profile: testProfile,
                group: groupLag,
                l10n: AppLocalizations.of(context)!,
              ),
            ),
          ),
        ),
      ),
    );
  }

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'three members render one row each with host and partition count',
    (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          group(
            members: [
              member(
                'm-1',
                assignments: const [
                  TopicPartition(topic: 'orders', partition: 0),
                ],
              ),
              member(
                'm-2',
                assignments: const [
                  TopicPartition(topic: 'orders', partition: 1),
                  TopicPartition(topic: 'orders', partition: 2),
                ],
              ),
              member('m-3'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (final id in ['m-1', 'm-2', 'm-3']) {
        expect(
          find.byKey(Key('group_member_$id')),
          findsOneWidget,
          reason: 'member $id should have a row',
        );
      }
      expect(find.text('10.0.0.7'), findsNWidgets(3));
      expect(find.text('1 partitions'), findsOneWidget);
      expect(find.text('2 partitions'), findsOneWidget);
      expect(find.text('0 partitions'), findsOneWidget);
    },
  );

  testWidgets('a group without members shows an empty state, not a blank row', (
    tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest(group()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('group_member_empty')), findsOneWidget);
    expect(find.text('This group currently has no members.'), findsOneWidget);
  });

  testWidgets('assignment follows the group state after a rebalance', (
    tester,
  ) async {
    Finder assignmentIn(String memberKey, String partition) => find.descendant(
      of: find.byKey(Key('group_member_$memberKey')),
      matching: find.byKey(Key('group_assignment_$partition')),
    );
    const before = [
      TopicPartition(topic: 'orders', partition: 0),
      TopicPartition(topic: 'orders', partition: 1),
    ];

    await tester.pumpWidget(
      createWidgetUnderTest(
        group(
          members: [
            member('m-1', assignments: before),
            member('m-2'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('group_member_m-1')),
        matching: find.text('m-1-client'),
      ),
    );
    await tester.pumpAndSettle();
    expect(assignmentIn('m-1', 'orders-0'), findsOneWidget);
    expect(assignmentIn('m-1', 'orders-1'), findsOneWidget);

    // Collapse again so the next expansion is unambiguous.
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('group_member_m-1')),
        matching: find.text('m-1-client'),
      ),
    );
    await tester.pumpAndSettle();

    // Rebalance: partition 1 moved to m-2.
    await tester.pumpWidget(
      createWidgetUnderTest(
        group(
          members: [
            member(
              'm-1',
              assignments: const [
                TopicPartition(topic: 'orders', partition: 0),
              ],
            ),
            member(
              'm-2',
              assignments: const [
                TopicPartition(topic: 'orders', partition: 1),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('group_member_m-2')),
        matching: find.text('m-2-client'),
      ),
    );
    await tester.pumpAndSettle();
    expect(assignmentIn('m-2', 'orders-1'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('group_member_m-1')),
        matching: find.text('m-1-client'),
      ),
    );
    await tester.pumpAndSettle();
    expect(assignmentIn('m-1', 'orders-0'), findsOneWidget);
    // The moved partition no longer belongs to m-1.
    expect(assignmentIn('m-1', 'orders-1'), findsNothing);
    expect(assignmentIn('m-2', 'orders-0'), findsNothing);
  });

  testWidgets('a partition owned by nobody is reported with its number', (
    tester,
  ) async {
    await tester.pumpWidget(
      createWidgetUnderTest(
        group(
          members: [
            member(
              'm-1',
              assignments: const [
                TopicPartition(topic: 'orders', partition: 0),
              ],
            ),
          ],
          unassigned: const [
            TopicPartition(topic: 'orders', partition: 1),
            TopicPartition(topic: 'orders', partition: 2),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('group_unassigned_chip')), findsOneWidget);
    expect(find.text('2 partitions have no owner'), findsOneWidget);
    expect(find.byKey(const Key('group_unassigned_orders-1')), findsOneWidget);
    expect(find.byKey(const Key('group_unassigned_orders-2')), findsOneWidget);
  });

  testWidgets('an undecodable assignment is named, not shown as empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      createWidgetUnderTest(group(members: [member('m-1', decodable: false)])),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('group_member_m-1')),
        matching: find.text('m-1-client'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Assignment could not be decoded'), findsOneWidget);
  });
}
