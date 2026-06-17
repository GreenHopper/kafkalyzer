class TextPreviewUtils {
  /// Safely truncates the payload for preview purposes, replacing newlines with spaces.
  /// If the text is longer than [maxLength], it truncates and appends an ellipsis.
  static String getPayloadPreview(String? payload, {int maxLength = 300}) {
    if (payload == null || payload.isEmpty) {
      return "";
    }

    String preview = payload;
    if (preview.length > maxLength) {
      preview = "${preview.substring(0, maxLength)}...";
    }

    // Replace newlines and multiple spaces for a compact single-line preview
    return preview.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
