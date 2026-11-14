import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/navigation/main_navigation_controller.dart';

void main() {
  test('select notifies only on change', () {
    final controller = MainNavigationController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    expect(controller.destination, MainDestination.explorer);
    controller.select(MainDestination.explorer);
    expect(notifications, 0);

    controller.select(MainDestination.settings);
    expect(controller.destination, MainDestination.settings);
    expect(controller.railIndex, 3);
    expect(notifications, 1);
  });

  test('openConsumerGroup and openScript requests are taken once', () {
    final controller = MainNavigationController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.openConsumerGroup('group-a');
    expect(controller.destination, MainDestination.consumerLag);
    expect(notifications, 1);
    expect(controller.takeConsumerGroupRequest(), 'group-a');
    expect(controller.takeConsumerGroupRequest(), isNull);

    controller.openScript('script-1');
    expect(controller.destination, MainDestination.scripts);
    expect(notifications, 2);
    expect(controller.takeScriptRequest(), 'script-1');
    expect(controller.takeScriptRequest(), isNull);
  });
}
