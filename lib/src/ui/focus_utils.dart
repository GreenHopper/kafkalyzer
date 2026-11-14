import 'package:material_ui/material_ui.dart';

/// Returns `true` when keyboard focus is currently inside a text input
/// widget (`EditableText` or one of its descendants such as `TextField`).
bool isTextInputFocused() {
  final primaryFocus = FocusManager.instance.primaryFocus;
  if (primaryFocus == null) return false;
  final context = primaryFocus.context;
  if (context == null) return false;
  return context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null;
}
