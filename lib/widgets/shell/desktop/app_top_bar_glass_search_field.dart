import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_glass_search_field_chrome.dart';

/// 概览页透明顶栏使用的液态玻璃搜索框。
///
/// 使用库的 [GlassTextField.search] 而不是 [GlassSearchBar]，因为当前顶栏
/// 搜索框还承载「文字图搜 / 图片图搜」两个后缀动作，[GlassSearchBar] 没有
/// 任意 suffix 槽位。后缀按钮保持透明，避免在玻璃内部再叠一层玻璃。
class AppTopBarGlassSearchField extends StatelessWidget {
  const AppTopBarGlassSearchField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    this.onSubmitted,
    this.onImageSearchTap,
    this.onTextImageSearchTap,
    this.imageSearchButtonKey,
    this.textImageSearchButtonKey,
    this.showImageSearchButton = false,
    this.showTextImageSearchButton = false,
  });

  static const double height = 32;

  final Key? fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onImageSearchTap;
  final VoidCallback? onTextImageSearchTap;
  final Key? imageSearchButtonKey;
  final Key? textImageSearchButtonKey;
  final bool showImageSearchButton;
  final bool showTextImageSearchButton;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final suffix = showImageSearchButton || showTextImageSearchButton
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (showTextImageSearchButton)
                AppIconButton(
                  key: textImageSearchButtonKey,
                  tooltip: l10n.widgetSearchTextImageTooltip,
                  semanticLabel: l10n.widgetSearchTextImageTooltip,
                  iconColor: context.appTextPalette.secondary,
                  icon: const Icon(Icons.text_fields_rounded),
                  onPressed: onTextImageSearchTap,
                ),
              if (showImageSearchButton)
                AppIconButton(
                  key: imageSearchButtonKey,
                  tooltip: l10n.widgetSearchImageSearchTooltip,
                  semanticLabel: l10n.widgetSearchImageSearchTooltip,
                  iconColor: context.appTextPalette.secondary,
                  icon: const Icon(Icons.image_search_outlined),
                  onPressed: onImageSearchTap,
                ),
            ],
          )
        : null;

    return buildAppGlassSearchField(
      key: fieldKey,
      context: context,
      controller: controller,
      focusNode: focusNode,
      placeholder: hintText,
      height: height,
      suffixIcon: suffix,
      onSubmitted: onSubmitted,
    );
  }
}
