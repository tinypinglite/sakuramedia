import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

class CatalogSearchField extends StatelessWidget {
  const CatalogSearchField({
    super.key,
    this.fieldKey,
    this.searchButtonKey,
    this.imageSearchButtonKey,
    this.textImageSearchButtonKey,
    this.onlineToggleKey,
    required this.controller,
    this.focusNode,
    required this.hintText,
    this.onSubmitted,
    this.onSearchTap,
    this.onImageSearchTap,
    this.onTextImageSearchTap,
    this.showSearchButton = true,
    this.showImageSearchButton = false,
    this.showTextImageSearchButton = false,
    this.showOnlineToggle = false,
    this.isOnlineSearchEnabled = false,
    this.onOnlineSearchToggle,
    this.isSearching = false,
    this.showSearchingIndicator = true,
    this.searchButtonTooltip,
    this.contentPadding,
    this.tightSuffix = false,
    this.borderRadius,
  });

  final Key? fieldKey;
  final Key? searchButtonKey;
  final Key? imageSearchButtonKey;
  final Key? textImageSearchButtonKey;
  final Key? onlineToggleKey;
  final TextEditingController controller;

  /// 外部持有的焦点节点；用于快捷键（如 Cmd/Ctrl+K）聚焦输入框。
  final FocusNode? focusNode;

  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onSearchTap;
  final VoidCallback? onImageSearchTap;
  final VoidCallback? onTextImageSearchTap;
  final bool showSearchButton;
  final bool showImageSearchButton;
  final bool showTextImageSearchButton;
  final bool showOnlineToggle;
  final bool isOnlineSearchEnabled;
  final ValueChanged<bool>? onOnlineSearchToggle;

  /// 搜索请求进行中：禁用后缀搜索按钮避免重复提交。
  final bool isSearching;

  /// 搜索进行中是否把后缀搜索图标换成转圈。
  ///
  /// 当页面已有独立的加载指示（如结果区中央 spinner）时，可传 `false` 保持
  /// 图标不转圈，只做置灰禁用。
  final bool showSearchingIndicator;

  /// 后缀搜索图标的 tooltip / 语义标签；为空时用通用搜索文案。
  final String? searchButtonTooltip;

  /// 覆盖默认内容内边距；用于塞进固定高度顶栏等紧凑场景。
  final EdgeInsetsGeometry? contentPadding;

  /// 收紧后缀图标的最小占位约束；紧凑顶栏用它解除 48px 触控热区下限，
  /// 让输入框高度能压到后缀按钮本身的高度。
  final bool tightSuffix;

  /// 覆盖默认圆角；紧凑顶栏等场景可收紧得更方。
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final searchTooltip =
        searchButtonTooltip ?? l10n.widgetSearchDefaultTooltip;
    return AppTextField(
      fieldKey: fieldKey,
      controller: controller,
      focusNode: focusNode,
      hintText: hintText,
      textInputAction: TextInputAction.search,
      onFieldSubmitted: onSubmitted,
      contentPadding: contentPadding,
      tightSuffix: tightSuffix,
      borderRadius: borderRadius,
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTextImageSearchButton)
            AppIconButton(
              key: textImageSearchButtonKey,
              tooltip: l10n.widgetSearchTextImageTooltip,
              semanticLabel: l10n.widgetSearchTextImageTooltip,
              iconColor: context.appTextPalette.primary,
              icon: const Icon(Icons.text_fields_rounded),
              onPressed: onTextImageSearchTap,
            ),
          if (showImageSearchButton)
            AppIconButton(
              key: imageSearchButtonKey,
              tooltip: l10n.widgetSearchImageSearchTooltip,
              semanticLabel: l10n.widgetSearchImageSearchTooltip,
              iconColor: context.appTextPalette.primary,
              icon: const Icon(Icons.image_search_outlined),
              onPressed: onImageSearchTap,
            ),
          if (showOnlineToggle)
            AppIconButton(
              key: onlineToggleKey,
              tooltip: l10n.widgetSearchOnlineToggleTooltip,
              semanticLabel: l10n.widgetSearchOnlineToggleTooltip,
              icon: const Icon(Icons.public_rounded),
              isSelected: isOnlineSearchEnabled,
              onPressed: onOnlineSearchToggle == null
                  ? null
                  : () => onOnlineSearchToggle!(!isOnlineSearchEnabled),
            ),
          if (showSearchButton)
            AppIconButton(
              key: searchButtonKey,
              tooltip: searchTooltip,
              semanticLabel: searchTooltip,
              iconColor: context.appTextPalette.primary,
              icon: isSearching && showSearchingIndicator
                  ? SizedBox(
                      width: context.appComponentTokens.iconSizeMd,
                      height: context.appComponentTokens.iconSizeMd,
                      child: const CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.search_rounded),
              onPressed: isSearching ? null : onSearchTap,
            ),
        ],
      ),
    );
  }
}
