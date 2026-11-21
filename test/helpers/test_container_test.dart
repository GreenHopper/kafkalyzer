import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';

import '../helpers/test_container.dart';

class _SubstitutedClusters extends ClusterListController {
  String get label => 'substitute';
}

/// Stands for a dependency no run provides: nothing ever registers it.
class _NeverProvided {}

/// Reads its controller the way screens are supposed to: a constructor
/// parameter that falls back to the application container.
class _Reader extends StatelessWidget {
  _Reader({ClusterListController? clusters})
    : clusters = clusters ?? getIt<ClusterListController>();

  final ClusterListController clusters;

  @override
  Widget build(BuildContext context) {
    final controller = clusters;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        controller is _SubstitutedClusters ? controller.label : 'session',
      ),
    );
  }
}

void main() {
  testWidgets('a supplied substitute reaches the screen', (tester) async {
    provideSubstitute<ClusterListController>(_SubstitutedClusters());

    await tester.pumpWidget(_Reader());

    expect(find.text('substitute'), findsOneWidget);
  });

  testWidgets('the next screen gets the session instance again', (
    tester,
  ) async {
    await tester.pumpWidget(_Reader());

    expect(find.text('session'), findsOneWidget);
    expect(getIt<ClusterListController>(), isNot(isA<_SubstitutedClusters>()));
  });

  test('a dependency the run did not provide fails with its type', () {
    expect(() => getIt<_NeverProvided>(), throwsA(isA<StateError>()));
  });
}
