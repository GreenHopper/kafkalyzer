import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

class MessageSearchBar extends StatefulWidget {
  final String searchPhrase;
  final ValueChanged<String> onSearchChanged;
  final int matchCount;
  final bool showNonMatches;
  final ValueChanged<bool> onShowNonMatchesChanged;

  const MessageSearchBar({
    super.key,
    required this.searchPhrase,
    required this.onSearchChanged,
    required this.matchCount,
    required this.showNonMatches,
    required this.onShowNonMatchesChanged,
  });

  @override
  State<MessageSearchBar> createState() => _MessageSearchBarState();
}

class _MessageSearchBarState extends State<MessageSearchBar> {
  Timer? _debounce;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchPhrase);
  }

  @override
  void didUpdateWidget(covariant MessageSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchPhrase != oldWidget.searchPhrase) {
      if (_controller.text != widget.searchPhrase) {
        _controller.text = widget.searchPhrase;
        _controller.selection = TextSelection.collapsed(
          offset: widget.searchPhrase.length,
        );
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.onSearchChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.searchPhrase.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Text(
              AppLocalizations.of(context)!.stepMatches(widget.matchCount),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        SizedBox(
          width: 300,
          height: 36,
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchResults,
              prefixIcon: const Icon(Icons.search, size: 16),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              suffixIcon: IntrinsicWidth(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () {
                          _controller.clear();
                          _onTextChanged("");
                        },
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                    IconButton(
                      tooltip: widget.showNonMatches
                          ? "Hide non-matching messages"
                          : "Show non-matches as dimmed",
                      icon: Icon(
                        widget.showNonMatches
                            ? Icons.visibility
                            : Icons.visibility_off,
                        size: 16,
                        color: widget.showNonMatches
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                      ),
                      onPressed: () => widget.onShowNonMatchesChanged(
                        !widget.showNonMatches,
                      ),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),
              ),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: _onTextChanged,
          ),
        ),
      ],
    );
  }
}
