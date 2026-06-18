import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class HexViewer extends StatelessWidget {
  final List<int> bytes;

  const HexViewer({super.key, required this.bytes});

  @override
  Widget build(BuildContext context) {
    if (bytes.isEmpty) {
      return const Center(child: Text("Empty binary data"));
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textStyle = GoogleFonts.robotoMono(
      fontSize: 13,
      color: colorScheme.onSurface,
    );

    // Build the hex dump string
    final buffer = StringBuffer();
    for (var i = 0; i < bytes.length; i += 16) {
      // Address
      buffer.write('${i.toRadixString(16).padLeft(8, '0')}  ');

      // Hex bytes
      for (var j = 0; j < 16; j++) {
        if (i + j < bytes.length) {
          buffer.write('${bytes[i + j].toRadixString(16).padLeft(2, '0')} ');
        } else {
          buffer.write('   ');
        }
        if (j == 7) {
          buffer.write(' '); // Extra space after 8 bytes
        }
      }

      buffer.write(' |');

      // ASCII
      for (var j = 0; j < 16; j++) {
        if (i + j < bytes.length) {
          final byte = bytes[i + j];
          if (byte >= 32 && byte <= 126) {
            buffer.writeCharCode(byte);
          } else {
            buffer.write('.');
          }
        }
      }

      buffer.write('|\n');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: buffer.toString()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Hex dump copied to clipboard")),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text("Copy Hex Dump"),
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
            child: SingleChildScrollView(
              child: SelectableText(buffer.toString(), style: textStyle),
            ),
          ),
        ),
      ],
    );
  }
}
