import 'package:material_ui/material_ui.dart';

/// Scrolls the nearest **vertical** ancestor so [context] is visible.
///
/// Unlike [Scrollable.ensureVisible], horizontal ancestors such as
/// [TabBarView] / [PageView] are ignored. That avoids sideways layout
/// shifts when keyboard message stepping auto-scrolls a list that sits
/// inside a tab shell.
Future<void> ensureVisibleVertically(
  BuildContext context, {
  double alignment = 0.0,
  Duration duration = Duration.zero,
  Curve curve = Curves.ease,
  ScrollPositionAlignmentPolicy alignmentPolicy =
      ScrollPositionAlignmentPolicy.explicit,
}) {
  final renderObject = context.findRenderObject();
  if (renderObject == null || !renderObject.attached) {
    return Future<void>.value();
  }

  ScrollableState? scrollable = Scrollable.maybeOf(context);
  while (scrollable != null) {
    final axis = axisDirectionToAxis(scrollable.axisDirection);
    if (axis == Axis.vertical) {
      return scrollable.position.ensureVisible(
        renderObject,
        alignment: alignment,
        duration: duration,
        curve: curve,
        alignmentPolicy: alignmentPolicy,
      );
    }
    scrollable = scrollable.context.findAncestorStateOfType<ScrollableState>();
  }
  return Future<void>.value();
}
