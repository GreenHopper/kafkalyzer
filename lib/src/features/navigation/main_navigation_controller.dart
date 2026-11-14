import 'package:material_ui/material_ui.dart';

/// Top-level navigation destinations matching the `NavigationRail` order.
enum MainDestination { explorer, consumerLag, scripts, settings }

/// Holds the active top-level destination and one-shot cross-destination
/// reveal requests for Consumer Lag groups and Scripts.
class MainNavigationController extends ChangeNotifier {
  MainDestination _destination = MainDestination.explorer;
  String? _pendingConsumerGroupId;
  String? _pendingScriptId;

  MainDestination get destination => _destination;
  int get railIndex => _destination.index;

  void select(MainDestination destination) {
    if (_destination == destination) return;
    _destination = destination;
    notifyListeners();
  }

  void selectIndex(int index) {
    if (index < 0 || index >= MainDestination.values.length) return;
    select(MainDestination.values[index]);
  }

  /// Requests switching to [MainDestination.consumerLag] and revealing [groupId].
  void openConsumerGroup(String groupId) {
    _pendingConsumerGroupId = groupId;
    _destination = MainDestination.consumerLag;
    notifyListeners();
  }

  /// Returns and clears the pending consumer group reveal request, if any.
  String? takeConsumerGroupRequest() {
    final id = _pendingConsumerGroupId;
    _pendingConsumerGroupId = null;
    return id;
  }

  /// Requests switching to [MainDestination.scripts] and selecting [scriptId].
  void openScript(String scriptId) {
    _pendingScriptId = scriptId;
    _destination = MainDestination.scripts;
    notifyListeners();
  }

  /// Returns and clears the pending script selection request, if any.
  String? takeScriptRequest() {
    final id = _pendingScriptId;
    _pendingScriptId = null;
    return id;
  }
}
