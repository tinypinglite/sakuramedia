import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_chrome_settings.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_quality.dart';

/// 统一的液态玻璃文本输入基座。
///
/// 用 [FormField] 保留 Material 表单的校验和 autovalidate 语义，输入面本身
/// 交给 `liquid_glass_widgets` 的 [GlassTextField] 绘制。label / helper / error
/// 留在玻璃面外侧，避免错误和长说明把玻璃输入撑成内容卡片。
class AppTextField extends StatefulWidget {
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
    this.inputFormatters,
    this.onTapOutside,
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
  final List<TextInputFormatter>? inputFormatters;
  final TapRegionCallback? onTapOutside;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final AutovalidateMode? autovalidateMode;
  final int? maxLines;
  final int? minLines;
  final bool isDense;

  /// 覆盖默认内容内边距；用于塞进固定高度顶栏等紧凑场景。
  final EdgeInsetsGeometry? contentPadding;

  /// 覆盖玻璃 tint；高对比度/实色回退时作为输入面填充色。
  final Color? fillColor;

  /// 覆盖默认圆角；映射到液态玻璃形状。
  final BorderRadius? borderRadius;

  /// 覆盖默认正文样式（默认 `resolveAppTextStyle(context, size: AppTextSize.s14)`）。
  /// 用于 JSON / 代码等需要等宽字体的编辑区。
  final TextStyle? style;

  /// 固定输入面的高度；为空时沿用多行内容自适应高度。
  final double? height;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final GlobalKey<FormFieldState<String>> _formFieldKey =
      GlobalKey<FormFieldState<String>>();

  late TextEditingController _effectiveController;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _attachController();
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    _detachController();
    _attachController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncFormValue();
      }
    });
  }

  @override
  void dispose() {
    _detachController();
    super.dispose();
  }

  void _attachController() {
    if (widget.controller == null) {
      _effectiveController = TextEditingController();
      _ownsController = true;
    } else {
      _effectiveController = widget.controller!;
      _ownsController = false;
    }
    _effectiveController.addListener(_syncFormValue);
  }

  void _detachController() {
    _effectiveController.removeListener(_syncFormValue);
    if (_ownsController) {
      _effectiveController.dispose();
    }
  }

  void _syncFormValue() {
    final field = _formFieldKey.currentState;
    if (field == null || field.value == _effectiveController.text) {
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncFormValue();
        }
      });
      return;
    }
    field.didChange(_effectiveController.text);
  }

  @override
  Widget build(BuildContext context) {
    final formTokens = context.appFormTokens;
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final inheritedFontFamily = resolveAppFontFamily(context);
    final resolvedRadius =
        (widget.borderRadius ?? context.appRadius.smBorder).topLeft.x;
    final textStyle =
        (widget.style ??
                resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.primary,
                ))
            .copyWith(
              fontFamily: widget.style?.fontFamily ?? inheritedFontFamily,
            );
    final placeholderStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s14,
      weight: AppTextWeight.regular,
      tone: AppTextTone.muted,
    ).copyWith(fontFamily: inheritedFontFamily);
    final baseSettings = highContrast ? null : appGlassHeaderSettings(context);
    final glassSettings = baseSettings == null
        ? null
        : widget.fillColor == null
        ? baseSettings
        : baseSettings.copyWith(glassColor: widget.fillColor!);
    final padding =
        widget.contentPadding ??
        EdgeInsets.symmetric(
          horizontal: formTokens.fieldHorizontalPadding,
          vertical:
              formTokens.fieldVerticalPadding +
              (widget.isDense ? 0 : context.appSpacing.xs),
        );
    final maxLines = widget.obscureText ? 1 : (widget.maxLines ?? 1);
    final minLines = widget.obscureText ? null : widget.minLines;

    return FormField<String>(
      key: _formFieldKey,
      initialValue: _effectiveController.text,
      enabled: widget.enabled,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode ?? AutovalidateMode.disabled,
      builder: (field) {
        Widget glassField = GlassTextField(
          key: widget.fieldKey,
          controller: _effectiveController,
          focusNode: widget.focusNode,
          placeholder: widget.hintText,
          prefixIcon: widget.prefix,
          suffixIcon: widget.suffix,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          maxLines: maxLines,
          minLines: minLines,
          enabled: true,
          readOnly: !widget.enabled,
          inputFormatters: widget.inputFormatters,
          onChanged: (value) {
            field.didChange(value);
            widget.onChanged?.call(value);
          },
          onSubmitted: widget.onFieldSubmitted,
          onTapOutside: widget.onTapOutside,
          textStyle: textStyle,
          placeholderStyle: placeholderStyle,
          padding: padding,
          iconSpacing: widget.tightSuffix
              ? context.appSpacing.xs
              : context.appSpacing.sm,
          height: widget.height,
          shape: LiquidRoundedSuperellipse(borderRadius: resolvedRadius),
          settings: glassSettings,
          useOwnLayer: !highContrast,
          quality: highContrast ? null : AppGlassQuality.input,
          surfaceStyle: highContrast
              ? GlassSurfaceStyle.solid
              : GlassSurfaceStyle.glass,
          color: highContrast
              ? (widget.fillColor ?? context.appColors.surfaceMuted)
              : null,
          interactionBehavior: highContrast || reduceMotion || !widget.enabled
              ? GlassInteractionBehavior.none
              : GlassInteractionBehavior.glowOnly,
        );
        if (!widget.enabled) {
          glassField = Semantics(
            container: true,
            textField: true,
            enabled: false,
            readOnly: true,
            label: widget.label ?? widget.hintText,
            value: _effectiveController.text,
            child: ExcludeSemantics(
              child: ExcludeFocus(
                child: IgnorePointer(
                  child: Opacity(opacity: 0.55, child: glassField),
                ),
              ),
            ),
          );
        }
        if (highContrast) {
          glassField = DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(resolvedRadius),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: glassField,
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.label != null && widget.label!.isNotEmpty) ...[
              Text(
                widget.label!,
                softWrap: true,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.secondary,
                ),
              ),
              SizedBox(height: formTokens.labelGap),
            ],
            glassField,
            if (field.hasError) ...[
              SizedBox(height: context.appSpacing.xs),
              Semantics(
                liveRegion: true,
                child: Text(
                  field.errorText!,
                  softWrap: true,
                  maxLines: 10,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.error,
                  ),
                ),
              ),
            ] else if (widget.helperText != null &&
                widget.helperText!.isNotEmpty) ...[
              SizedBox(height: context.appSpacing.xs),
              Text(
                widget.helperText!,
                softWrap: true,
                maxLines: 10,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.muted,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
