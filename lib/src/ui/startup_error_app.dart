import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/services/diagnostics/redaction.dart';
import 'package:kafkalyzer/src/services/file_opener_service.dart';
import 'package:logger/logger.dart';

class StartupErrorApp extends StatelessWidget {
  final Object error;
  final StackTrace? stack;
  final String? logPath;
  final FileOpenerService? fileOpenerService;

  const StartupErrorApp({
    super.key,
    required this.error,
    this.stack,
    this.logPath,
    this.fileOpenerService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kafkalyzer',
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _StartupErrorScreen(
        error: error,
        stack: stack,
        logPath: logPath,
        fileOpenerService: fileOpenerService,
      ),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  final Object error;
  final StackTrace? stack;
  final String? logPath;
  final FileOpenerService? fileOpenerService;

  const _StartupErrorScreen({
    required this.error,
    required this.stack,
    required this.logPath,
    this.fileOpenerService,
  });

  String _formattedDetails() {
    final buffer = StringBuffer()
      ..writeln('Error: ${formatSafeError(error)}')
      ..writeln(
        'OS: ${Platform.operatingSystem} (${Platform.operatingSystemVersion})',
      )
      ..writeln('Log file: ${logPath ?? 'unavailable'}');
    if (stack != null) {
      buffer.writeln('Stack trace:');
      for (final line in stack.toString().trimRight().split('\n').take(20)) {
        buffer.writeln('  ${redact(line)}');
      }
    }
    return buffer.toString().trimRight();
  }

  Future<void> _copyDetails(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: _formattedDetails()));
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.errorDetailsCopied)));
    } catch (_) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.errorDetailsCopyFailed)));
    }
  }

  Future<void> _openLogFolder(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final path = logPath;
    if (path == null || path.isEmpty) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n.settingsOpenLogFolderFailed(l10n.diagnosticsUnavailable),
            ),
          ),
        );
      return;
    }
    final opener = fileOpenerService ?? FileOpenerService(logger: Logger());
    final ok = await opener.showInFolder(path);
    if (!ok) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(l10n.settingsOpenLogFolderFailed(path))),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final details = _formattedDetails();
    final displayPath = (logPath != null && logPath!.isNotEmpty)
        ? logPath!
        : l10n.diagnosticsUnavailable;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: colorScheme.error,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.startupFailureTitle,
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(l10n.startupFailureBody),
                    const SizedBox(height: 12),
                    Text(
                      '${l10n.startupFailureLogPathLabel}: $displayPath',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 240),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          details,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _copyDetails(context),
                          icon: const Icon(Icons.copy),
                          label: Text(l10n.errorCopyDetails),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openLogFolder(context),
                          icon: const Icon(Icons.folder_open),
                          label: Text(l10n.settingsOpenLogFolder),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
