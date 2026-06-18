import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kafkalyzer/src/utils/payload_processing_isolate.dart';
import 'package:kafkalyzer/src/utils/app_fonts.dart';

class HexViewer extends StatefulWidget {
  final List<int> bytes;

  const HexViewer({super.key, required this.bytes});

  @override
  State<HexViewer> createState() => _HexViewerState();
}

class _HexViewerState extends State<HexViewer> {
  bool _isGenerating = true;
  String _hexOutput = "";
  bool _isTruncated = false;

  @override
  void initState() {
    super.initState();
    _generateHexAsync();
  }

  @override
  void didUpdateWidget(covariant HexViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bytes != widget.bytes) {
      _generateHexAsync();
    }
  }

  Future<void> _generateHexAsync() async {
    setState(() {
      _isGenerating = true;
      _isTruncated = false;
    });

    // Generate hex dump in background isolate
    String fullHex = await generateHexDumpInIsolate(widget.bytes);

    if (mounted) {
      const maxLength = 500000;
      if (fullHex.length > maxLength) {
        _hexOutput = fullHex.substring(0, maxLength);
        _isTruncated = true;
      } else {
        _hexOutput = fullHex;
      }

      setState(() {
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bytes.isEmpty) {
      return const Center(child: Text("Empty binary data"));
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textStyle = AppFonts.robotoMono(
      fontSize: 13,
      color: colorScheme.onSurface,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                // If it's too large to generate quickly on main thread, we could spawn another isolate to generate it again for copy.
                // But clipboard might crash on 8MB anyway.
                // We will let it be slow for copy if user REALLY wants it.
                // Wait, generateHexDumpInIsolate returns the full string, but we discarded it from memory.
                // Let's just generate it again for clipboard.
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text("Preparing hex dump for clipboard..."),
                  ),
                );
                generateHexDumpInIsolate(widget.bytes).then((fullHex) {
                  Clipboard.setData(ClipboardData(text: fullHex));
                  if (mounted) {
                    scaffoldMessenger.hideCurrentSnackBar();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text("Hex dump copied to clipboard"),
                      ),
                    );
                  }
                });
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text("Copy Full Hex Dump"),
            ),
          ],
        ),
        if (_isTruncated)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            color: colorScheme.errorContainer,
            child: Row(
              children: [
                Icon(
                  Icons.warning,
                  color: colorScheme.onErrorContainer,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Display truncated to 500k characters for performance. Use 'Copy Full Hex Dump' to extract the complete data.",
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: _isGenerating
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: SelectableText(_hexOutput, style: textStyle),
                  ),
          ),
        ),
      ],
    );
  }
}
