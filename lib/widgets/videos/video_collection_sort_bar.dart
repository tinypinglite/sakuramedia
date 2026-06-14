import 'package:flutter/material.dart';
import 'package:sakuramedia/features/videos/presentation/video_filter_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';

/// 视频合集详情的内联排序工具条：手动顺序 + 视频列表排序字段 + 升降序，均即时生效。
///
/// 与全部视频页的 `VideoFilterToolbar` 同款 chip，保证排序选项视觉对齐；额外把
/// 「手动顺序」（[VideoSortField]? 为 `null`）作为首个选项。手动顺序固定升序，
/// 故选中时隐藏方向切换；其余字段沿用全部视频页的字段标签与方向语义。
class VideoCollectionSortBar extends StatelessWidget {
  const VideoCollectionSortBar({
    super.key,
    required this.sortField,
    required this.sortDirection,
    required this.onChanged,
  });

  /// 当前排序字段；为 `null` 表示手动顺序（position）。
  final VideoSortField? sortField;
  final SortDirection sortDirection;

  /// 排序变化回调：[field] 为 `null` 表示切回手动顺序；[direction] 为 `null` 表示沿用当前方向。
  final void Function({
    required VideoSortField? field,
    SortDirection? direction,
  }) onChanged;

  @override
  Widget build(BuildContext context) {
    final isManual = sortField == null;
    return Wrap(
      spacing: context.appSpacing.sm,
      runSpacing: context.appSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppTextButton(
          key: const Key('video-collection-sort-manual'),
          label: '手动顺序',
          size: AppTextButtonSize.small,
          backgroundStyle: AppTextButtonBackgroundStyle.muted,
          isSelected: isManual,
          onPressed: () => onChanged(field: null),
        ),
        for (final field in VideoSortField.values)
          AppTextButton(
            key: Key('video-collection-sort-${field.apiValue}'),
            label: field.label,
            size: AppTextButtonSize.small,
            backgroundStyle: AppTextButtonBackgroundStyle.muted,
            isSelected: field == sortField,
            onPressed: () => onChanged(field: field),
          ),
        // 手动顺序固定升序，隐藏方向切换；其余字段可切升降序。
        if (!isManual)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.appSpacing.xs),
            child: AppTextButton(
              key: const Key('video-collection-sort-direction'),
              label: sortDirection.label,
              icon: Icon(
                sortDirection == SortDirection.desc
                    ? Icons.south_rounded
                    : Icons.north_rounded,
              ),
              size: AppTextButtonSize.small,
              backgroundStyle: AppTextButtonBackgroundStyle.muted,
              onPressed: () => onChanged(
                field: sortField,
                direction: sortDirection == SortDirection.desc
                    ? SortDirection.asc
                    : SortDirection.desc,
              ),
            ),
          ),
      ],
    );
  }
}
