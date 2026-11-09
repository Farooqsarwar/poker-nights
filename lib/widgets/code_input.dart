import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import 'glass_styles.dart';

/// The large, centred, widely tracked field for typing an invite or game
/// code (A6 "ENTER CODE", A7 "CODE"). Same surface as [AppTextField] so the
/// two read as one family; only the type is different.
class CodeInput extends StatefulWidget {
  const CodeInput({
    super.key,
    required this.controller,
    this.hint = 'CODE',
    this.semanticLabel,
    this.autofocus = false,
    this.enabled = true,
    this.hasError = false,
    this.maxLength,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;

  /// Read by screen readers in place of the visual eyebrow above the field.
  final String? semanticLabel;
  final bool autofocus;
  final bool enabled;
  final bool hasError;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<CodeInput> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focused != _focus.hasFocus) {
        setState(() => _focused = _focus.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.code();
    return Semantics(
      textField: true,
      label: widget.semanticLabel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: Glass.glassInput(
          focused: _focused,
          hasError: widget.hasError,
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          autofocus: widget.autofocus,
          enabled: widget.enabled,
          maxLength: widget.maxLength,
          inputFormatters: widget.inputFormatters,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          style: style,
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            counterText: '',
            hintText: widget.hint,
            hintStyle: style.copyWith(color: AppColors.onSurfaceHint),
            isDense: true,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
