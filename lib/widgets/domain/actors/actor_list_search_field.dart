import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

/// 女优列表的搜索入口：只占一个图标位，点击就地展开搜索框。
///
/// 关键词生效中（或搜索框展开中）时高亮，桌面 / 移动列表头共用。
class ActorListSearchToggle extends StatelessWidget {
  const ActorListSearchToggle({
    super.key,
    required this.isActive,
    required this.onTap,
    required this.tooltip,
  });

  final bool isActive;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return AppGlassIconButton(
      icon: Icons.search_rounded,
      tooltip: tooltip,
      semanticLabel: tooltip,
      foregroundColor: isActive ? Theme.of(context).colorScheme.primary : null,
      onPressed: onTap,
    );
  }
}

/// 女优列表就地展开的搜索输入框：插入即自动聚焦，有内容时显示清空按钮。
///
/// 关键词变更即回调，请求防抖由列表筛选机制负责；收起由调用方的
/// [ActorListSearchToggle] 负责，收起时保留关键词。
class ActorListSearchField extends StatefulWidget {
  const ActorListSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.fieldKey,
    this.clearButtonKey,
    this.hintText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final Key? fieldKey;
  final Key? clearButtonKey;

  /// 输入框占位文案；为 `null` 时使用当前语言的默认文案。
  final String? hintText;

  @override
  State<ActorListSearchField> createState() => _ActorListSearchFieldState();
}

class _ActorListSearchFieldState extends State<ActorListSearchField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleControllerChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppTextField(
      fieldKey: widget.fieldKey,
      controller: widget.controller,
      focusNode: _focusNode,
      hintText: widget.hintText ?? l10n.widgetActorSearchHint,
      contentPadding: EdgeInsets.symmetric(
        horizontal: context.appFormTokens.fieldHorizontalPadding,
        vertical: context.appSpacing.sm,
      ),
      tightSuffix: true,
      suffix: widget.controller.text.isEmpty
          ? null
          : AppIconButton(
              key: widget.clearButtonKey,
              icon: const Icon(Icons.close_rounded),
              tooltip: l10n.widgetActorClearSearch,
              semanticLabel: l10n.widgetActorClearSearch,
              size: AppIconButtonSize.mini,
              onPressed: () {
                widget.controller.clear();
                widget.onChanged('');
              },
            ),
      onChanged: widget.onChanged,
    );
  }
}
