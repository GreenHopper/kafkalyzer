import 'package:flutter/foundation.dart';

/// Global timestamp display mode used for message timestamps and epoch tooltips.
enum TimeDisplayMode { local, utc }

/// Holds the global [TimeDisplayMode] so tree tooltips and timestamp views
/// react when the user switches between Local and UTC.
class TimeDisplaySettings extends ValueNotifier<TimeDisplayMode> {
  TimeDisplaySettings([super.value = TimeDisplayMode.local]);

  static final TimeDisplaySettings fallback = TimeDisplaySettings();

  bool get isUtc => value == TimeDisplayMode.utc;

  void setMode(TimeDisplayMode mode) {
    if (value != mode) {
      value = mode;
    }
  }
}
