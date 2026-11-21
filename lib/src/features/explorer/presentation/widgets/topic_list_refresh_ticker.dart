import 'dart:async';

/// Repaints a widget on a fixed interval. The timer factory is injectable so a
/// test can drive ticks with fake async instead of waiting real seconds.
class TopicListRefreshTicker {
  static const Duration defaultInterval = Duration(seconds: 30);

  final Duration interval;
  final Timer Function(Duration interval, void Function() onTick) timerFactory;

  Timer? _timer;

  TopicListRefreshTicker({
    this.interval = defaultInterval,
    Timer Function(Duration interval, void Function() onTick)? timerFactory,
  }) : timerFactory = timerFactory ?? _periodic;

  static Timer _periodic(Duration interval, void Function() onTick) =>
      Timer.periodic(interval, (_) => onTick());

  void start(void Function() onTick) {
    cancel();
    _timer = timerFactory(interval, onTick);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  bool get isRunning => _timer != null;
}
