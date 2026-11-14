import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/services/secure_storage_service.dart';

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

  Widget _buildKeyringIndicator(
    BuildContext context,
    AppLocalizations? l10n,
    bool unavailable,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    if (unavailable) {
      return Tooltip(
        message:
            l10n?.passwordsNotPersistedTooltip ??
            'System keyring is unavailable. This password will not be persisted across restarts.',
        child: Padding(
          padding: const EdgeInsets.only(right: 4.0),
          child: Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: colorScheme.error,
          ),
        ),
      );
    }
    return Tooltip(
      message: l10n?.protectedByOsKeyring ?? 'Protected by OS Keyring',
      child: Padding(
        padding: const EdgeInsets.only(right: 4.0),
        child: Icon(
          Icons.lock_outline,
          size: 16,
          color: colorScheme.primary.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ValueListenable<bool>? unavailableListenable =
        getIt.isRegistered<SecureStorageService>()
        ? getIt<SecureStorageService>().unavailable
        : null;

    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unavailableListenable != null)
              ValueListenableBuilder<bool>(
                valueListenable: unavailableListenable,
                builder: (context, unavailable, _) =>
                    _buildKeyringIndicator(context, l10n, unavailable),
              )
            else
              _buildKeyringIndicator(context, l10n, false),
            IconButton(
              icon: Icon(
                _obscured
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
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
          ],
        ),
      ),
      validator: widget.validator,
    );
  }
}
