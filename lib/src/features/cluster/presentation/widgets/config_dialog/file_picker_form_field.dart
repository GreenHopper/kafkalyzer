import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

class FilePickerFormField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final List<String>? allowedExtensions;
  final String? Function(String?)? validator;

  const FilePickerFormField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.allowedExtensions,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        suffixIcon: IconButton(
          icon: const Icon(Icons.folder_open),
          tooltip: l10n?.browseFiles ?? 'Browse files',
          onPressed: () async {
            final result = await FilePicker.pickFiles(
              type: allowedExtensions != null ? FileType.custom : FileType.any,
              allowedExtensions: allowedExtensions,
            );
            if (result != null && result.files.single.path != null) {
              controller.text = result.files.single.path!;
            }
          },
        ),
      ),
      validator: validator,
    );
  }
}
