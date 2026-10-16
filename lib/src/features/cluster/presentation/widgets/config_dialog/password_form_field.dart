import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

class PasswordFormField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final String? Function(String?)? validator;

  const PasswordFormField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.validator,
  });

  @override
  State<PasswordFormField> createState() => _PasswordFormFieldState();
}

class _PasswordFormFieldState extends State<PasswordFormField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        suffixIcon: IconButton(
          icon: Icon(
            _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          tooltip: _obscured
              ? (l10n?.showPassword ?? 'Show password')
              : (l10n?.hidePassword ?? 'Hide password'),
          onPressed: () {
            setState(() {
              _obscured = !_obscured;
            });
          },
        ),
      ),
      validator: widget.validator,
    );
  }
}
