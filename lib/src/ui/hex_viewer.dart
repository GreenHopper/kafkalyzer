import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/utils/app_fonts.dart';
import 'package:kafkalyzer/src/utils/payload_processing_isolate.dart';
import 'package:material_ui/material_ui.dart';

class HexViewer extends StatefulWidget {
  final Uint8List bytes;
  final ScrollController? scrollController;

  const HexViewer({super.key, required this.bytes, this.scrollController});

  @override
  State<HexViewer> createState() => _HexViewerState();
}

class _HexViewerState extends State<HexViewer> {
  static const double _rowExtent = 20.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (widget.bytes.isEmpty) {
      return Center(child: Text(l10n?.emptyBinaryData ?? 'Empty binary data'));
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textStyle = AppFonts.robotoMono(
      fontSize: 13,
      height: 1.4,
      color: colorScheme.onSurface,
    );
    final rowCount = (widget.bytes.length + 15) ~/ 16;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final preparingText =
                    l10n?.preparingHexDump ??
                    'Preparing hex dump for clipboard...';
                final copiedText =
                    l10n?.hexDumpCopied ?? 'Hex dump copied to clipboard';
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text(preparingText)),
                );
                generateHexDumpInIsolate(widget.bytes).then((fullHex) {
                  Clipboard.setData(ClipboardData(text: fullHex));
                  if (mounted) {
                    scaffoldMessenger.hideCurrentSnackBar();
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text(copiedText)),
                    );
                  }
                });
              },
              icon: const Icon(Icons.copy, size: 16),
              label: Text(l10n?.copyFullHexDump ?? 'Copy Full Hex Dump'),
            ),
          ],
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = math.max(constraints.maxWidth, 680.0);
                return SelectionArea(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: contentWidth,
                      height: constraints.maxHeight,
                      child: ListView.builder(
                        controller: widget.scrollController,
                        itemCount: rowCount,
                        itemExtent: _rowExtent,
                        itemBuilder: (context, index) {
                          return Text(
                            formatHexRow(widget.bytes, index),
                            style: textStyle,
                            maxLines: 1,
                            softWrap: false,
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
