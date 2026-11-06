import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/tags/data/tag_list_item_dto.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_state.dart';
import 'package:sakuramedia/features/tags/presentation/tag_placeholders.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_chip.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/domain/tags/app_tag_match_mode_toggle.dart';

/// 标签多选区：已选标签 chips + 热门/搜索结果标签云（可选可收起搜索框）。
///
/// 影片库筛选面板传 [collapsibleSearch] 和更小的 [collapsedTagCount]
/// 走精简形态；女优标签面板传 `showSearch: false` / `showCloudHeader: false`
/// 直接展示全部作品标签，不复用热门分组。
class TagSelectorPanel extends StatefulWidget {
  const TagSelectorPanel({
    super.key,
    required this.selection,
    required this.onToggleTag,
    required this.onRemoveTag,
    required this.onClear,
    required this.onMatchModeChanged,
    required this.onRetry,
    this.onQueryChanged,
    this.onToggleExpanded,
    this.title,
    this.keyPrefix = 'tags',
    this.showSearch = true,
    this.showCloudHeader = true,
    this.showMatchModeToggle = true,
    this.collapsibleSearch = false,
    this.collapsedTagCount = 24,
    this.showTagCounts = true,
  });

  final TagSelectionState selection;
  final ValueChanged<int> onToggleTag;
  final ValueChanged<int> onRemoveTag;
  final VoidCallback onClear;
  final ValueChanged<String>? onQueryChanged;
  final VoidCallback? onToggleExpanded;
  final ValueChanged<TagMatchMode> onMatchModeChanged;
  final VoidCallback onRetry;

  /// 顶部标题；为 `null` 时使用当前语言的默认文案。
  final String? title;

  /// 控件 Key 前缀，用于区分同一页面上的多个标签选择器。
  final String keyPrefix;

  /// 是否展示搜索框。女优详情的标签面板直接展示全部标签，传 `false`。
  final bool showSearch;

  /// 是否展示「热门标签 / 搜索结果」小标题和展开入口。女优详情不分组，传 `false`。
  final bool showCloudHeader;

  /// 是否展示「任一/全部」匹配模式开关。视频域多标签固定为 OR（后端无 tag_match），
  /// 传 `false` 以隐藏该开关，避免出现无效控件。
  final bool showMatchModeToggle;

  /// 搜索框是否默认收起：`true` 时标题行只显示搜索图标，点开才展开输入框
  /// （再点收起并清空关键词）。筛选面板里的分节用它来省空间。
  final bool collapsibleSearch;

  /// 收起态标签云展示的标签数量上限；超出才显示「展开全部」。
  final int collapsedTagCount;

  /// 标签 chips 是否带影片数量。标签页靠数量做选择参考；筛选面板里省空间不显示。
  final bool showTagCounts;

  @override
  State<TagSelectorPanel> createState() => _TagSelectorPanelState();
}

class _TagSelectorPanelState extends State<TagSelectorPanel> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late bool _searchExpanded;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.selection.searchQuery,
    );
    _searchFocusNode = FocusNode();
    _searchExpanded = widget.showSearch && !widget.collapsibleSearch;
    // 懒加载 scope 在面板打开时才拉取标签。
    if (!widget.selection.hasLoadedOnce &&
        !widget.selection.isLoading &&
        widget.selection.errorMessage == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onRetry();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    if (_searchExpanded) {
      // 收起搜索时清掉关键词，避免"搜索生效但输入框不可见"。
      _searchController.clear();
      widget.onQueryChanged?.call('');
      _searchFocusNode.unfocus();
    }
    setState(() => _searchExpanded = !_searchExpanded);
    if (_searchExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selection = widget.selection;
    final spacing = context.appSpacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.title ?? l10n.widgetTagSelectorTitle,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.medium,
                tone: AppTextTone.primary,
              ),
            ),
            const Spacer(),
            if (widget.showSearch && widget.collapsibleSearch)
              AppIconButton(
                key: Key('${widget.keyPrefix}-search-toggle'),
                icon: const Icon(Icons.search_rounded),
                semanticLabel: l10n.widgetTagSearchHint,
                size: AppIconButtonSize.mini,
                isSelected:
                    _searchExpanded || _searchController.text.isNotEmpty,
                onPressed: _toggleSearch,
              ),
            if (widget.showSearch &&
                widget.collapsibleSearch &&
                selection.hasSelection &&
                widget.showMatchModeToggle)
              SizedBox(width: spacing.sm),
            if (selection.hasSelection && widget.showMatchModeToggle)
              _buildMatchModeToggle(context),
          ],
        ),
        if (widget.showSearch && _searchExpanded) ...[
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: Key('${widget.keyPrefix}-search-field'),
            controller: _searchController,
            focusNode: _searchFocusNode,
            hintText: l10n.widgetTagSearchHint,
            prefix: Icon(
              Icons.search,
              size: context.appComponentTokens.iconSizeSm,
              color: context.appTextPalette.secondary,
            ),
            suffix: _searchController.text.isEmpty
                ? null
                : AppIconButton(
                    icon: Icon(
                      Icons.close,
                      size: context.appComponentTokens.iconSizeSm,
                    ),
                    tooltip: l10n.baseClearSearch,
                    size: AppIconButtonSize.mini,
                    onPressed: () {
                      _searchController.clear();
                      widget.onQueryChanged?.call('');
                    },
                  ),
            onChanged: widget.onQueryChanged,
          ),
        ],
        SizedBox(height: spacing.md),
        _buildBody(context),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            label: l10n.commonRetry,
            size: AppTextButtonSize.xSmall,
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
        if (widget.showCloudHeader) ...[
          _buildCloudHeader(context),
          SizedBox(height: spacing.sm),
        ],
        _buildCloud(context),
      ],
    );
  }

  Widget _buildLoading(BuildContext context) {
    // loading 用占位标签渲染真实药丸，由 [AppSkeletonizer] 灰化。
    return AppSkeletonizer(
      key: Key('${widget.keyPrefix}-selector-skeleton'),
      enabled: true,
      child: _buildCloudWrap(context, tagListItemPlaceholders()),
    );
  }

  Widget _buildSelectedSection(BuildContext context) {
    final selection = widget.selection;
    final spacing = context.appSpacing;
    return Wrap(
      spacing: spacing.sm,
      runSpacing: spacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final tag in selection.selectedTags)
          AppFilterChip(
            key: Key('${widget.keyPrefix}-selected-${tag.tagId}'),
            label: tag.name,
            selected: true,
            trailing: const Icon(Icons.close),
            onPressed: () => widget.onRemoveTag(tag.tagId),
          ),
        AppTextButton(
          key: Key('${widget.keyPrefix}-clear-all'),
          label: AppLocalizations.of(context).widgetTagClearAll,
          size: AppTextButtonSize.xSmall,
          onPressed: widget.onClear,
        ),
      ],
    );
  }

  Widget _buildMatchModeToggle(BuildContext context) {
    final selection = widget.selection;
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.widgetTagMatchLabel,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(width: spacing.sm),
        AppTagMatchModeToggle(
          matchMode: selection.matchMode,
          buttonKeyPrefix: '${widget.keyPrefix}-match',
          onChanged: widget.onMatchModeChanged,
        ),
      ],
    );
  }

  Widget _buildCloudHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selection = widget.selection;
    final headerLabel = selection.isSearching
        ? l10n.widgetTagSearchResult
        : l10n.widgetTagPopular;
    return Row(
      children: [
        Text(
          headerLabel,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        const Spacer(),
        if (widget.onToggleExpanded != null &&
            !selection.isSearching &&
            selection.filteredTags.length > widget.collapsedTagCount)
          AppTextButton(
            label: selection.expanded
                ? l10n.widgetTagCollapse
                : l10n.widgetTagExpandAll,
            size: AppTextButtonSize.xSmall,
            trailingIcon: Icon(
              selection.expanded ? Icons.expand_less : Icons.expand_more,
            ),
            onPressed: widget.onToggleExpanded,
          ),
      ],
    );
  }

  Widget _buildEmptyCloudMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Text(
      widget.selection.isSearching
          ? l10n.widgetTagNoMatch
          : l10n.widgetTagEmpty,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        weight: AppTextWeight.regular,
        tone: AppTextTone.muted,
      ),
    );
  }

  Widget _buildCloud(BuildContext context) {
    final selection = widget.selection;
    final tags = selection.filteredTags;

    if (tags.isEmpty) {
      return _buildEmptyCloudMessage(context);
    }

    // 收起态（非搜索）仅展示前 [TagSelectorPanel.collapsedTagCount] 个；
    // 展开或搜索时完整展示。按数量裁剪，确保「展开全部」只在确有隐藏项时出现。
    final showAll =
        !widget.showCloudHeader ||
        widget.onToggleExpanded == null ||
        selection.isSearching ||
        selection.expanded;
    final visibleTags = showAll || tags.length <= widget.collapsedTagCount
        ? tags
        : tags.sublist(0, widget.collapsedTagCount);
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
          AppFilterChip(
            key: Key('${widget.keyPrefix}-option-${tag.tagId}'),
            label: widget.showTagCounts
                ? '${tag.name} · ${tag.movieCount}'
                : tag.name,
            selected: selection.isSelected(tag.tagId),
            onPressed: () => widget.onToggleTag(tag.tagId),
          ),
      ],
    );
  }
}
