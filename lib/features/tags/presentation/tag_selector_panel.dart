import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/presentation/movie_filter_state.dart';
import 'package:sakuramedia/features/tags/data/tag_list_item_dto.dart';
import 'package:sakuramedia/features/tags/presentation/tag_selection_controller.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

/// 标签多选区：搜索框 + 已选标签 chips + 热门/搜索结果标签云。
///
/// 桌面端与移动端标签页共用同一套选择交互，仅外层布局/滚动各自处理。
class TagSelectorPanel extends StatefulWidget {
  const TagSelectorPanel({
    super.key,
    required this.selection,
    required this.onToggleTag,
    required this.onRemoveTag,
    required this.onClear,
    required this.onQueryChanged,
    required this.onToggleExpanded,
    required this.onMatchModeChanged,
    required this.onRetry,
  });

  final TagSelectionController selection;
  final ValueChanged<int> onToggleTag;
  final ValueChanged<int> onRemoveTag;
  final VoidCallback onClear;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onToggleExpanded;
  final ValueChanged<TagMatchMode> onMatchModeChanged;
  final VoidCallback onRetry;

  @override
  State<TagSelectorPanel> createState() => _TagSelectorPanelState();
}

class _TagSelectorPanelState extends State<TagSelectorPanel> {
  /// 收起态（非搜索）标签云展示的标签数量上限，约对应三行；超出才显示「展开全部」。
  static const int _collapsedCloudLimit = 24;

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.selection.searchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.selection;
    final spacing = context.appSpacing;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(spacing.lg),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '选择标签',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.medium,
                  tone: AppTextTone.primary,
                ),
              ),
              const Spacer(),
              if (selection.hasSelection)
                Text(
                  '已选 ${selection.selectedCount} 个',
                  key: const Key('tags-selected-count'),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
            ],
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('tags-search-field'),
            controller: _searchController,
            hintText: '搜索标签',
            prefix: Icon(
              Icons.search,
              size: context.appComponentTokens.iconSizeSm,
              color: context.appTextPalette.secondary,
            ),
            suffix: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(
                      Icons.close,
                      size: context.appComponentTokens.iconSizeSm,
                    ),
                    splashRadius: 16,
                    onPressed: () {
                      _searchController.clear();
                      widget.onQueryChanged('');
                    },
                  ),
            onChanged: widget.onQueryChanged,
          ),
          SizedBox(height: spacing.md),
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final selection = widget.selection;
    final spacing = context.appSpacing;

    if (selection.isLoading && !selection.hasLoadedOnce) {
      return _buildLoading(context);
    }

    if (selection.errorMessage != null && !selection.hasLoadedOnce) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppEmptyState(message: selection.errorMessage!),
          SizedBox(height: spacing.sm),
          AppTextButton(
            label: '重试',
            size: AppTextButtonSize.xSmall,
            backgroundStyle: AppTextButtonBackgroundStyle.muted,
            onPressed: widget.onRetry,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selection.hasSelection) ...[
          _buildSelectedSection(context),
          SizedBox(height: spacing.md),
        ],
        _buildCloudHeader(context),
        SizedBox(height: spacing.sm),
        _buildCloud(context),
      ],
    );
  }

  Widget _buildLoading(BuildContext context) {
    final spacing = context.appSpacing;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        SizedBox(width: spacing.sm),
        Text(
          '标签加载中',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedSection(BuildContext context) {
    final selection = widget.selection;
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '已选标签',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
            const Spacer(),
            _buildMatchModeToggle(context),
          ],
        ),
        SizedBox(height: spacing.sm),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final tag in selection.selectedTags)
              AppTextButton(
                key: Key('tags-selected-${tag.tagId}'),
                label: tag.name,
                size: AppTextButtonSize.xSmall,
                backgroundStyle: AppTextButtonBackgroundStyle.muted,
                isSelected: true,
                trailingIcon: const Icon(Icons.close),
                onPressed: () => widget.onRemoveTag(tag.tagId),
              ),
            AppTextButton(
              key: const Key('tags-clear-all'),
              label: '清空',
              size: AppTextButtonSize.xSmall,
              onPressed: widget.onClear,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMatchModeToggle(BuildContext context) {
    final selection = widget.selection;
    final spacing = context.appSpacing;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '匹配',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(width: spacing.sm),
        AppTextButton(
          key: const Key('tags-match-or'),
          label: TagMatchMode.or.label,
          size: AppTextButtonSize.xSmall,
          backgroundStyle: AppTextButtonBackgroundStyle.muted,
          isSelected: selection.matchMode == TagMatchMode.or,
          onPressed: () => widget.onMatchModeChanged(TagMatchMode.or),
        ),
        SizedBox(width: spacing.sm),
        AppTextButton(
          key: const Key('tags-match-and'),
          label: TagMatchMode.and.label,
          size: AppTextButtonSize.xSmall,
          backgroundStyle: AppTextButtonBackgroundStyle.muted,
          isSelected: selection.matchMode == TagMatchMode.and,
          onPressed: () => widget.onMatchModeChanged(TagMatchMode.and),
        ),
      ],
    );
  }

  Widget _buildCloudHeader(BuildContext context) {
    final selection = widget.selection;
    return Row(
      children: [
        Text(
          selection.isSearching ? '搜索结果' : '热门标签',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        const Spacer(),
        if (!selection.isSearching &&
            selection.visibleTags.length > _collapsedCloudLimit)
          AppTextButton(
            label: selection.expanded ? '收起' : '展开全部',
            size: AppTextButtonSize.xSmall,
            trailingIcon: Icon(
              selection.expanded ? Icons.expand_less : Icons.expand_more,
            ),
            onPressed: widget.onToggleExpanded,
          ),
      ],
    );
  }

  Widget _buildCloud(BuildContext context) {
    final selection = widget.selection;
    final tags = selection.visibleTags;

    if (tags.isEmpty) {
      return Text(
        selection.isSearching ? '未找到匹配的标签' : '暂无标签',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.regular,
          tone: AppTextTone.muted,
        ),
      );
    }

    // 收起态（非搜索）仅展示前 _collapsedCloudLimit 个，约三行；
    // 展开或搜索时完整展示。按数量裁剪，确保「展开全部」只在确有隐藏项时出现。
    final showAll = selection.isSearching || selection.expanded;
    final visibleTags = showAll || tags.length <= _collapsedCloudLimit
        ? tags
        : tags.sublist(0, _collapsedCloudLimit);
    return _buildCloudWrap(context, visibleTags);
  }

  Widget _buildCloudWrap(BuildContext context, List<TagListItemDto> tags) {
    final selection = widget.selection;
    final spacing = context.appSpacing;
    return Wrap(
      spacing: spacing.sm,
      runSpacing: spacing.sm,
      children: [
        for (final tag in tags)
          AppTextButton(
            key: Key('tags-option-${tag.tagId}'),
            label: '${tag.name} · ${tag.movieCount}',
            size: AppTextButtonSize.xSmall,
            backgroundStyle: AppTextButtonBackgroundStyle.muted,
            isSelected: selection.isSelected(tag.tagId),
            onPressed: () => widget.onToggleTag(tag.tagId),
          ),
      ],
    );
  }
}
