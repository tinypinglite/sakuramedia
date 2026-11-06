import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_glass_search_field_chrome.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';

/// 页面内使用的液态玻璃搜索框。
///
/// 与顶栏搜索框共用 iOS 27 glass settings，但保持页面级尺寸和清空交互；
/// 业务页面只负责筛选策略，输入框本身不持有筛选状态。
class AppGlassSearchField extends StatelessWidget {
  const AppGlassSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.fieldKey,
    this.clearKey,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final Key? fieldKey;
  final Key? clearKey;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return buildAppGlassSearchField(
          key: fieldKey,
          context: context,
          controller: controller,
          placeholder: hintText,
          height: 40,
          prefixIcon: Icon(
            Icons.search_rounded,
            size: context.appComponentTokens.iconSizeSm,
            color: context.appTextPalette.muted,
          ),
          suffixIcon: value.text.isEmpty
              ? null
              : AppIconButton(
                  key: clearKey,
                  tooltip: l10n.baseClearSearch,
                  semanticLabel: l10n.baseClearSearch,
                  size: AppIconButtonSize.compact,
                  iconColor: context.appTextPalette.secondary,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                  },
                ),
          onChanged: onChanged,
        );
      },
    );
  }
}
