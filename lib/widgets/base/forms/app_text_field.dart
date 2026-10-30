import 'package:material_ui/material_ui.dart';
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
    this.tightSuffix = false,
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
    this.contentPadding,
    this.fillColor,
    this.borderRadius,
    this.style,
    this.height,
  });

  final Key? fieldKey;

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? label;
  final String? helperText;
  final Widget? prefix;
  final Widget? suffix;
  final bool tightSuffix;
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

  /// 覆盖默认内容内边距；用于塞进固定高度顶栏等紧凑场景。
  final EdgeInsetsGeometry? contentPadding;

  /// 覆盖默认的填充色（默认 `context.appColors.surfaceMuted`）。
  /// 用于把输入框放到比 `surfaceMuted` 更暗的面板上（如侧边栏）需要提升对比度的场景。
  final Color? fillColor;

  /// 覆盖默认圆角（`context.appRadius.smBorder`）；紧凑顶栏等场景可收紧到
  /// 更方的 [AppRadius.xsBorder]。
  final BorderRadius? borderRadius;

  /// 覆盖默认正文样式（默认 `resolveAppTextStyle(context, size: AppTextSize.s14)`）。
  /// 用于 JSON / 代码等需要等宽字体的编辑区。
  final TextStyle? style;

  /// 固定输入框填充面的高度；为空时沿用内容自适应高度。
  final double? height;

  @override
  Widget build(BuildContext context) {
    final formTokens = context.appFormTokens;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null && label!.isNotEmpty) ...[
          Text(
            label!,
            softWrap: true,
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
          textAlignVertical: height == null ? null : TextAlignVertical.center,
          style: style ?? resolveAppTextStyle(context, size: AppTextSize.s14),
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
      borderRadius: borderRadius ?? context.appRadius.smBorder,
      borderSide: BorderSide(color: color),
    );

    return InputDecoration(
      hintText: hintText,
      helperText: helperText,
      // 后端下发的说明/校验文案可能很长：不设置时 Flutter 只显示单行省略。
      // 给足行数让它换行显示全（实际只占文本真实高度），桌面/移动共用。
      helperMaxLines: 10,
      errorMaxLines: 10,
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
      constraints: height == null
          ? null
          : BoxConstraints.tightFor(height: height),
      isDense: isDense,
      filled: true,
      fillColor: fillColor ?? colors.surfaceMuted,
      contentPadding:
          contentPadding ??
          EdgeInsets.symmetric(
            horizontal: formTokens.fieldHorizontalPadding,
            vertical: formTokens.fieldVerticalPadding,
          ),
      prefixIcon: prefix == null
          ? null
          : Padding(
              padding: EdgeInsets.only(
                left: context.appSpacing.md,
                right: context.appSpacing.sm,
              ),
              child: height == null
                  ? prefix
                  : SizedBox(
                      height: height,
                      child: Align(
                        alignment: Alignment.center,
                        widthFactor: 1,
                        child: prefix,
                      ),
                    ),
            ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffix,
      // 默认沿用 Flutter 的 48×48 min（保证 AppIconButton 等 icon 型 suffix 的触控热区）；
      // 只有 tightSuffix=true 的文本型 suffix（例如单位「MB」「分钟」）才收紧到 0×0，让文本贴边。
      suffixIconConstraints: suffix != null && tightSuffix
          ? const BoxConstraints(minWidth: 0, minHeight: 0)
          : null,
      border: border(colors.borderSubtle),
      enabledBorder: border(colors.borderSubtle),
      focusedBorder: border(colors.borderSubtle),
      errorBorder: border(theme.colorScheme.error),
      focusedErrorBorder: border(theme.colorScheme.error),
      disabledBorder: border(colors.borderSubtle),
    );
  }
}
