import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

class ParameterValuesDialog extends StatefulWidget {
  final String parameterName;
  final List<String> values;
  final Set<String> initiallySelected;

  const ParameterValuesDialog({
    super.key,
    required this.parameterName,
    required this.values,
    this.initiallySelected = const {},
  });

  @override
  State<ParameterValuesDialog> createState() => _ParameterValuesDialogState();
}

class _ParameterValuesDialogState extends State<ParameterValuesDialog> {
  late Set<String> _selected;
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredValues = [];

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initiallySelected);
    _filteredValues = widget.values;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredValues = widget.values
          .where((v) => v.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Filter by ${widget.parameterName}",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: "Search values",
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () =>
                        setState(() => _selected.addAll(_filteredValues)),
                    child: const Text("Select All Matches"),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selected.clear()),
                    child: const Text("Clear Selection"),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredValues.length,
                  itemBuilder: (context, index) {
                    final value = _filteredValues[index];
                    return CheckboxListTile(
                      title: Text(value),
                      value: _selected.contains(value),
                      onChanged: (bool? checked) {
                        setState(() {
                          if (checked == true) {
                            _selected.add(value);
                          } else {
                            _selected.remove(value);
                          }
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      secondary: IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        tooltip: "Copy value",
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: value));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Copied '$value' to clipboard"),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: Text("Apply (${_selected.length})"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
