import 'package:flutter/material.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_filter_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart'
    show AppFilterPanelFooter, AppFilterPopover, AppFilterPopoverAlignment;

/// 「媒体管理」筛选工具栏：仿 `MovieFilterToolbar` 的 popover 触发按钮 +
/// 内部分节面板 + 底部重置。
///
/// 归属 / 所属媒体库 / 排序方式全部通过 chip 选择，避免 5 项排序挤在下拉里。
class MediaBrowseFilterToolbar extends StatelessWidget {
  const MediaBrowseFilterToolbar({
    super.key,
    required this.filterState,
    required this.libraries,
    required this.onChanged,
    required this.onReset,
  });

  final MediaBrowseFilterState filterState;
  final List<MediaLibraryDto> libraries;
  final ValueChanged<MediaBrowseFilterState> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    // 外层 Wrap 与 `MovieFilterToolbar` 对齐：`AppFilterTotalHeader` 把 leading
    // 放进 Expanded，直接返回 AppFilterPopover 会让 trigger 被拉满一整行、
    // 面板宽度跟着 `trigger + panelExtraWidth` 撑到全宽、位置也就跑偏。
    // Wrap 允许子件按内在宽度排布，trigger 保持内容大小，面板自然对齐它。
    return Wrap(
      spacing: context.appSpacing.sm,
      runSpacing: context.appSpacing.sm,
      children: [
        AppFilterPopover(
          triggerLabel: filterState.triggerLabel,
          triggerKey: const Key('media-management-filter-trigger'),
          labelKey: const Key('media-management-filter-trigger-label'),
          panelKey: const Key('media-management-filter-panel'),
          scrollViewKey: const Key('media-management-filter-scroll-view'),
          // 没有预设 chip 分担焦点，trigger 恒高亮（表明它就代表当前筛选态），
          // 与影片 `isDefault || isCustom` 效果一致。
          isSelected: true,
          highlightWhenOpen: false,
          panelExtraWidth: 240,
          // 面板 trigger 位于 leading 最左端，向右延伸自然填入内容区、不会
          // 反过来遮挡左侧配置分类栏（默认的 right-aligned 会往左溢出）。
          alignment: AppFilterPopoverAlignment.leftAlignedToTrigger,
          panelBuilder: (_) => MediaBrowseFilterSectionGroup(
            filterState: filterState,
            libraries: libraries,
            onChanged: onChanged,
          ),
          footer: AppFilterPanelFooter(
            isDefault: filterState.isDefault,
            onReset: onReset,
          ),
        ),
      ],
    );
  }
}

/// 面板内的分节 Column：归属 / 媒体库 / 排序，各自 chip 选择。
class MediaBrowseFilterSectionGroup extends StatelessWidget {
  const MediaBrowseFilterSectionGroup({
    super.key,
    required this.filterState,
    required this.libraries,
    required this.onChanged,
  });

  final MediaBrowseFilterState filterState;
  final List<MediaLibraryDto> libraries;
  final ValueChanged<MediaBrowseFilterState> onChanged;

  static const List<_KindOption> _kindOptions = [
    _KindOption(label: '全部', kind: null, itemKey: Key('media-kind-all')),
    _KindOption(
      label: 'JAV 影片',
      kind: MediaListItemKind.jav,
      itemKey: Key('media-kind-jav'),
    ),
    _KindOption(
      label: 'PornBox',
      kind: MediaListItemKind.video,
      itemKey: Key('media-kind-video'),
    ),
  ];

  /// 秒传状态 chip 顺序：先"全部"，再"未秒传"（最常用于找可秒传的候选），
  /// 然后按活跃度排"进行中→失败→待清理→未命中"。
  static const List<MediaBrowseRapidUploadFilter?> _rapidUploadOrder = [
    null,
    MediaBrowseRapidUploadFilter.none,
    MediaBrowseRapidUploadFilter.inProgress,
    MediaBrowseRapidUploadFilter.failed,
    MediaBrowseRapidUploadFilter.cleanupFailed,
    MediaBrowseRapidUploadFilter.notHit,
  ];

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(text: '归属'),
        SizedBox(height: spacing.sm),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          children: [
            for (final option in _kindOptions)
              AppTextButton(
                key: option.itemKey,
                label: option.label,
                size: AppTextButtonSize.xSmall,
                isSelected: filterState.kind == option.kind,
                onPressed: () => onChanged(
                  filterState.copyWith(
                    kind: option.kind,
                    resetKind: option.kind == null,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: spacing.lg),
        _SectionTitle(text: '所属媒体库'),
        SizedBox(height: spacing.sm),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          children: [
            AppTextButton(
              key: const Key('media-library-filter-all'),
              label: '全部媒体库',
              size: AppTextButtonSize.xSmall,
              isSelected: filterState.libraryId == null,
              onPressed: () => onChanged(filterState.copyWith(libraryId: null)),
            ),
            for (final library in libraries)
              AppTextButton(
                key: Key('media-library-filter-${library.id}'),
                label: library.displayLabel,
                size: AppTextButtonSize.xSmall,
                isSelected: filterState.libraryId == library.id,
                onPressed: () => onChanged(
                  filterState.copyWith(libraryId: library.id),
                ),
              ),
          ],
        ),
        SizedBox(height: spacing.lg),
        _SectionTitle(text: '秒传状态'),
        SizedBox(height: spacing.sm),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          children: [
            for (final filter in _rapidUploadOrder)
              AppTextButton(
                key: Key(
                  'media-rapid-upload-filter-${filter?.name ?? 'all'}',
                ),
                label: filter?.label ?? '全部',
                size: AppTextButtonSize.xSmall,
                isSelected: filterState.rapidUploadStatus == filter,
                onPressed: () => onChanged(
                  filterState.copyWith(rapidUploadStatus: filter),
                ),
              ),
          ],
        ),
        SizedBox(height: spacing.lg),
        _SectionTitle(text: '排序方式'),
        SizedBox(height: spacing.sm),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          children: [
            for (final field in MediaBrowseSortField.values)
              AppTextButton(
                key: Key('media-sort-field-${field.name}'),
                label: field.label,
                size: AppTextButtonSize.xSmall,
                isSelected: filterState.sortField == field,
                // 已选字段再点则清空，退回后端默认（入库时间倒序）。
                onPressed: () => onChanged(
                  filterState.copyWith(
                    sortField: filterState.sortField == field ? null : field,
                  ),
                ),
              ),
          ],
        ),
        if (filterState.sortField != null) ...[
          SizedBox(height: spacing.md),
          Wrap(
            spacing: spacing.sm,
            children: [
              for (final direction in MediaBrowseSortDirection.values)
                AppTextButton(
                  key: Key('media-sort-direction-${direction.name}'),
                  label: direction.label,
                  size: AppTextButtonSize.xSmall,
                  isSelected: filterState.sortDirection == direction,
                  onPressed: () => onChanged(
                    filterState.copyWith(sortDirection: direction),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s14,
        weight: AppTextWeight.regular,
        tone: AppTextTone.primary,
      ),
    );
  }
}

class _KindOption {
  const _KindOption({
    required this.label,
    required this.kind,
    required this.itemKey,
  });
  final String label;
  final MediaBrowseKindFilter kind;
  final Key itemKey;
}
