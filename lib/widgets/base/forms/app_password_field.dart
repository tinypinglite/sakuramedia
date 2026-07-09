import 'package:flutter/material.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

/// 密码输入框：包一层 [AppTextField] + 内置 obscure 状态 + 右侧可见性切换按钮。
///
/// 语义遵循 Material 惯例：obscure=true 时图标显示"眼睛(可见)"表示"点了会显示"，
/// obscure=false 时显示"划掉的眼睛"表示"点了会隐藏"。tooltip / semanticLabel 同步。
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    this.fieldKey,
    this.visibilityButtonKey,
    this.controller,
    this.focusNode,
    this.hintText,
    this.label,
    this.helperText,
    this.enabled = true,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.autovalidateMode,
    this.showLabel = '显示密码',
    this.hideLabel = '隐藏密码',
    this.iconButtonSize = AppIconButtonSize.compact,
    this.isDense = true,
  });

  final Key? fieldKey;
  final Key? visibilityButtonKey;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? label;
  final String? helperText;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final AutovalidateMode? autovalidateMode;
  final String showLabel;
  final String hideLabel;
  final AppIconButtonSize iconButtonSize;
  final bool isDense;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final actionLabel = _obscure ? widget.showLabel : widget.hideLabel;
    return AppTextField(
      fieldKey: widget.fieldKey,
      controller: widget.controller,
      focusNode: widget.focusNode,
      hintText: widget.hintText,
      label: widget.label,
      helperText: widget.helperText,
      enabled: widget.enabled,
      obscureText: _obscure,
      validator: widget.validator,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      autovalidateMode: widget.autovalidateMode,
      isDense: widget.isDense,
      suffix: AppIconButton(
        key: widget.visibilityButtonKey,
        tooltip: actionLabel,
        semanticLabel: actionLabel,
        size: widget.iconButtonSize,
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
        onPressed:
            widget.enabled
                ? () => setState(() {
                  _obscure = !_obscure;
                })
                : null,
      ),
    );
  }
}
