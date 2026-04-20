import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.fieldKey,
    this.controller,
    this.focusNode,
    this.hintText,
    this.label,
    this.helperText,
    this.prefix,
    this.suffix,
    this.obscureText = false,
    this.enabled = true,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.autovalidateMode,
    this.maxLines = 1,
    this.minLines,
    this.isDense = true,
  });

  final Key? fieldKey;

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? label;
  final String? helperText;
  final Widget? prefix;
  final Widget? suffix;
  final bool obscureText;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final AutovalidateMode? autovalidateMode;
  final int? maxLines;
  final int? minLines;
  final bool isDense;

  @override
  Widget build(BuildContext context) {
    final formTokens = context.appFormTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null && label!.isNotEmpty) ...[
          Text(
            label!,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: formTokens.labelGap),
        ],
        TextFormField(
          key: fieldKey,
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          enabled: enabled,
          validator: validator,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          onChanged: onChanged,
          autovalidateMode: autovalidateMode,
          maxLines: obscureText ? 1 : maxLines,
          minLines: obscureText ? 1 : minLines,
          style: resolveAppTextStyle(context, size: AppTextSize.s14),
          decoration: _buildDecoration(context),
        ),
      ],
    );
  }

  InputDecoration _buildDecoration(BuildContext context) {
    final theme = Theme.of(context);
    final formTokens = context.appFormTokens;
    final colors = context.appColors;

    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: context.appRadius.smBorder,
      borderSide: BorderSide(color: color),
    );

    return InputDecoration(
      hintText: hintText,
      helperText: helperText,
      hintStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s14,
        tone: AppTextTone.muted,
      ),
      helperStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        tone: AppTextTone.muted,
      ),
      errorStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        tone: AppTextTone.error,
      ),
      isDense: isDense,
      filled: true,
      fillColor: colors.surfaceMuted,
      contentPadding: EdgeInsets.symmetric(
        horizontal: formTokens.fieldHorizontalPadding,
        vertical: formTokens.fieldVerticalPadding,
      ),
      prefixIcon:
          prefix == null
              ? null
              : Padding(
                padding: EdgeInsets.only(
                  left: context.appSpacing.md,
                  right: context.appSpacing.sm,
                ),
                child: prefix,
              ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffix,
      border: border(colors.borderSubtle),
      enabledBorder: border(colors.borderSubtle),
      focusedBorder: border(colors.borderSubtle),
      errorBorder: border(theme.colorScheme.error),
      focusedErrorBorder: border(theme.colorScheme.error),
      disabledBorder: border(colors.borderSubtle),
    );
  }
}
