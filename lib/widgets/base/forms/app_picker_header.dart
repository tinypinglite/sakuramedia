import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_glass_search_field.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';

/// 左右导航动作需要保留的宽度，避免居中标题与按钮重叠。
const double _navActionSideReserve = 76;

/// 选择器弹层的统一头部。
///
/// 采用 iOS sheet 的导航栏结构：左侧关闭、中间标题、右侧完成。搜索框和
/// 筛选 chips 放在导航栏下方；选中计数由列表的 grouped section header 展示。
/// 搜索只做输入透传，防抖由调用方处理。
class AppPickerHeader extends StatelessWidget {
  const AppPickerHeader({
    super.key,
    required this.title,
    this.description,
    this.searchController,
    this.searchFieldKey,
    this.searchHintText,
    this.onSearchChanged,
    this.clearSearchKey,
    this.chips = const <Widget>[],
    this.onDone,
    this.doneKey,
    this.onClose,
    this.closeKey,
  });

  final String title;
  final String? description;

  final TextEditingController? searchController;
  final Key? searchFieldKey;
  final String? searchHintText;
  final ValueChanged<String>? onSearchChanged;
  final Key? clearSearchKey;

  /// 筛选 chips（`AppPickerIosChip`），横向可滚动。
  final List<Widget> chips;

  final VoidCallback? onDone;
  final Key? doneKey;
  final VoidCallback? onClose;
  final Key? closeKey;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final spacing = context.appSpacing;
    final accent = Theme.of(context).colorScheme.primary;
    final fontFamily = resolveAppFontFamily(context);
    final effectiveSearchController = searchController;
    final effectiveDone = onDone ?? onClose;

    Widget navAction({
      required String label,
      required VoidCallback? onPressed,
      Key? key,
    }) {
      return cupertino.CupertinoButton(
        key: key,
        minimumSize: const Size(64, 44),
        padding: EdgeInsets.symmetric(horizontal: spacing.xs),
        foregroundColor: accent,
        onPressed: onPressed,
        child: Text(
          label,
          maxLines: 1,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.medium,
            tone: AppTextTone.primary,
          ).copyWith(fontFamily: fontFamily, color: accent),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _navActionSideReserve,
                ),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s16,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ).copyWith(fontFamily: fontFamily),
                ),
              ),
              if (onClose != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: navAction(
                    key: closeKey,
                    label: l10n.baseClose,
                    onPressed: onClose,
                  ),
                ),
              if (effectiveDone != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: navAction(
                    key: doneKey,
                    label: l10n.commonDone,
                    onPressed: effectiveDone,
                  ),
                ),
            ],
          ),
        ),
        if (description != null && description!.trim().isNotEmpty) ...[
          SizedBox(height: spacing.xs),
          Text(
            description!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ).copyWith(fontFamily: fontFamily),
          ),
        ],
        if (effectiveSearchController != null) ...[
          SizedBox(height: spacing.md),
          AppGlassSearchField(
            fieldKey: searchFieldKey,
            clearKey: clearSearchKey,
            controller: effectiveSearchController,
            hintText: searchHintText ?? l10n.baseSearchHint,
            onChanged: onSearchChanged,
          ),
        ],
        if (chips.isNotEmpty) ...[
          SizedBox(
            height: effectiveSearchController == null ? spacing.sm : spacing.md,
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < chips.length; index++) ...[
                  if (index > 0) SizedBox(width: spacing.sm),
                  chips[index],
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
