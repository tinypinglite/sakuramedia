import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/taste_profile_provider.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/tags/data/tag_list_item_dto.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_provider.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_scope.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_state.dart';
import 'package:sakuramedia/features/tags/presentation/tag_placeholders.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_glass_search_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_surface.dart';

/// 标签页的浏览态：页面中心是一块可搜索、可多选的标签墙。
///
/// 选择先写进 [TagSelectionState] 作为草稿，点「查看影片」才由页面切入结果态；
/// 这样第一次点标签不会立刻离开当前上下文，多选和匹配模式也能在同一屏完成。
class TagBrowseSurface extends ConsumerStatefulWidget {
  const TagBrowseSurface({
    super.key,
    required this.scope,
    required this.mobile,
    required this.onConfirm,
    this.onCancel,
  });

  final TagSelectionScope scope;
  final bool mobile;
  final VoidCallback onConfirm;

  /// 从结果页进入浏览态时提供「取消」，用于恢复进入前的选择。
  final VoidCallback? onCancel;

  @override
  ConsumerState<TagBrowseSurface> createState() => _TagBrowseSurfaceState();
}

class _TagBrowseSurfaceState extends ConsumerState<TagBrowseSurface> {
  static const int _desktopPopularCount = 54;
  static const int _mobilePopularCount = 36;
  static const int _searchResultLimit = 120;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool get _isSearching => _query.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(tagSelectionProvider(widget.scope));
    final notifier = ref.read(tagSelectionProvider(widget.scope).notifier);
    final tasteTags = _tasteTags();
    final searchResults = _isSearching
        ? _searchTags(selection.allTags)
        : const <TagListItemDto>[];

    return Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            key: const Key('tags-browse-scroll'),
            padding: EdgeInsets.only(
              top: widget.mobile
                  ? context.appSpacing.lg
                  : context.appSpacing.xxl,
              bottom: context.appSpacing.xxl,
              left: widget.mobile ? 0 : context.appSpacing.xl,
              right: widget.mobile ? 0 : context.appSpacing.xl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _buildHero(context, selection),
                    if (selection.hasSelection) ...<Widget>[
                      SizedBox(height: context.appSpacing.lg),
                      _buildSelectedStrip(context, selection, notifier),
                    ],
                    SizedBox(height: context.appSpacing.xl),
                    _buildBody(
                      context,
                      selection: selection,
                      notifier: notifier,
                      tasteTags: tasteTags,
                      searchResults: searchResults,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildActionBar(context, selection, notifier),
      ],
    );
  }

  Widget _buildHero(BuildContext context, TagSelectionState selection) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Column(
      children: <Widget>[
        Text(
          l10n.tagBrowseTitle,
          textAlign: TextAlign.center,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s20,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.sm),
        Text(
          l10n.tagBrowseSubtitle,
          textAlign: TextAlign.center,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.xl),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: widget.mobile ? double.infinity : 360,
            ),
            child: widget.mobile
                ? AppGlassSearchField(
                    fieldKey: const Key('tags-browse-search'),
                    controller: _searchController,
                    hintText: l10n.tagSearchHint,
                    clearKey: const Key('tags-browse-search-clear'),
                    onChanged: (value) => setState(() => _query = value),
                  )
                : AppTextField(
                    fieldKey: const Key('tags-browse-search'),
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    enabled: selection.hasLoadedOnce,
                    hintText: l10n.tagSearchHint,
                    prefix: Icon(
                      Icons.search_rounded,
                      size: context.appComponentTokens.iconSizeSm,
                      color: context.appTextPalette.secondary,
                    ),
                    suffix: _query.isEmpty
                        ? null
                        : AppIconButton(
                            key: const Key('tags-browse-search-clear'),
                            icon: Icon(
                              Icons.close_rounded,
                              size: context.appComponentTokens.iconSizeSm,
                            ),
                            tooltip: l10n.baseClearSearch,
                            size: AppIconButtonSize.mini,
                            onPressed: _clearQuery,
                          ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: spacing.lg,
                      vertical: spacing.md,
                    ),
                    borderRadius: context.appRadius.mdBorder,
                    onChanged: (value) => setState(() => _query = value),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required TagSelectionState selection,
    required TagSelection notifier,
    required List<TagListItemDto> tasteTags,
    required List<TagListItemDto> searchResults,
  }) {
    if (selection.isLoading && !selection.hasLoadedOnce) {
      return _buildLoading(context);
    }
    if (selection.errorMessage != null && !selection.hasLoadedOnce) {
      return AppEmptyState(
        message: selection.errorMessage!,
        onRetry: () => unawaited(notifier.retry()),
      );
    }
    if (selection.allTags.isEmpty) {
      return AppEmptyState(message: AppLocalizations.of(context).tagEmpty);
    }
    if (_isSearching) {
      return _buildSearchResults(
        context,
        results: searchResults,
        selection: selection,
        notifier: notifier,
      );
    }

    final popularTags = _popularTags(selection.allTags, tasteTags);
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (tasteTags.isNotEmpty) ...<Widget>[
          _buildSectionHeader(
            context,
            icon: Icons.auto_awesome_rounded,
            label: l10n.tagForYou,
            trailing: l10n.tagForYouSubtitle,
          ),
          SizedBox(height: spacing.md),
          _buildCloudWrap(
            context,
            tags: tasteTags,
            personalized: true,
            selection: selection,
            onToggle: notifier.toggle,
          ),
          SizedBox(height: spacing.xxl),
        ],
        _buildSectionHeader(
          context,
          label: l10n.tagPopular,
          trailing: l10n.tagCountLabel(popularTags.length),
        ),
        SizedBox(height: spacing.md),
        _buildCloudWrap(
          context,
          tags: popularTags,
          personalized: false,
          selection: selection,
          onToggle: notifier.toggle,
        ),
        if (popularTags.length + tasteTags.length <
            selection.allTags.length) ...<Widget>[
          SizedBox(height: spacing.xl),
          Text(
            l10n.tagSearchFindsAll(selection.allTags.length),
            textAlign: TextAlign.center,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s10,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildSectionHeader(
          context,
          label: AppLocalizations.of(context).tagPopular,
        ),
        SizedBox(height: context.appSpacing.md),
        AppSkeletonizer(
          key: const Key('tags-browse-skeleton'),
          enabled: true,
          child: _buildCloudWrap(
            context,
            tags: tagListItemPlaceholders(count: 24),
            personalized: false,
            selection: null,
            onToggle: (_) {},
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(
    BuildContext context, {
    required List<TagListItemDto> results,
    required TagSelectionState selection,
    required TagSelection notifier,
  }) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final visible = results.take(_searchResultLimit).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildSectionHeader(
          context,
          label: l10n.tagSearchResults,
          trailing: l10n.tagCountLabel(results.length),
        ),
        SizedBox(height: spacing.md),
        if (results.isEmpty)
          AppEmptyState(message: l10n.tagNoMatch)
        else
          Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            children: <Widget>[
              for (final tag in visible)
                AppTextButton(
                  key: Key('tags-search-option-${tag.tagId}'),
                  label: '${tag.name} · ${tag.movieCount}',
                  size: AppTextButtonSize.xSmall,
                  isSelected: selection.isSelected(tag.tagId),
                  onPressed: () => notifier.toggle(tag.tagId),
                ),
            ],
          ),
        if (results.length > _searchResultLimit) ...<Widget>[
          SizedBox(height: spacing.md),
          Text(
            l10n.tagResultLimitHint(_searchResultLimit),
            textAlign: TextAlign.center,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s10,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectedStrip(
    BuildContext context,
    TagSelectionState selection,
    TagSelection notifier,
  ) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: spacing.sm,
      runSpacing: spacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          l10n.tagSelected,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        for (final tag in selection.selectedTags)
          AppTextButton(
            key: Key('tags-browse-selected-${tag.tagId}'),
            label: tag.name,
            size: AppTextButtonSize.xSmall,
            isSelected: true,
            trailingIcon: const Icon(Icons.close),
            onPressed: () => notifier.remove(tag.tagId),
          ),
        AppIconButton(
          key: const Key('tags-browse-clear'),
          tooltip: l10n.tagClear,
          semanticLabel: l10n.tagClear,
          size: AppIconButtonSize.compact,
          icon: const Icon(Icons.filter_alt_off_rounded),
          onPressed: notifier.clear,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String label,
    String? trailing,
    IconData? icon,
  }) {
    return Row(
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(
            icon,
            size: context.appComponentTokens.iconSize2xs,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(width: context.appSpacing.xs),
        ],
        Text(
          label,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.medium,
            tone: AppTextTone.secondary,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s10,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
      ],
    );
  }

  Widget _buildCloudWrap(
    BuildContext context, {
    required List<TagListItemDto> tags,
    required bool personalized,
    required TagSelectionState? selection,
    required ValueChanged<int> onToggle,
  }) {
    final spacing = context.appSpacing;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: widget.mobile ? spacing.lg : spacing.xl,
      runSpacing: widget.mobile ? spacing.sm : spacing.md,
      children: <Widget>[
        for (var index = 0; index < tags.length; index++)
          _TagCloudItem(
            key: Key(
              personalized
                  ? 'taste-cloud-tag-${tags[index].tagId}'
                  : 'tags-cloud-tag-${tags[index].tagId}',
            ),
            tag: tags[index],
            tier: personalized
                ? _personalizedTier(tags[index])
                : _tierFor(index, tags[index]),
            personalized: personalized,
            selected: selection?.isSelected(tags[index].tagId) ?? false,
            mobile: widget.mobile,
            onTap: () => onToggle(tags[index].tagId),
          ),
      ],
    );
  }

  Widget _buildActionBar(
    BuildContext context,
    TagSelectionState selection,
    TagSelection notifier,
  ) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.bottomCenter,
      child: selection.hasSelection
          ? widget.mobile
                ? _buildMobileActionBar(context, selection, notifier)
                : _buildDesktopActionBar(context, selection, notifier)
          : const SizedBox(width: double.infinity),
    );
  }

  Widget _buildDesktopActionBar(
    BuildContext context,
    TagSelectionState selection,
    TagSelection notifier,
  ) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      key: const Key('tags-browse-action-bar'),
      decoration: BoxDecoration(
        color: context.appColors.surfaceElevated,
        border: Border(top: BorderSide(color: context.appColors.divider)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.appSpacing.xl,
          vertical: context.appSpacing.md,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  l10n.tagSelectedCount(selection.selectedCount),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
                if (selection.selectedCount > 1) ...<Widget>[
                  SizedBox(width: context.appSpacing.md),
                  _MatchModeToggle(
                    selection: selection,
                    notifier: notifier,
                    mobile: false,
                  ),
                ],
                SizedBox(width: context.appSpacing.lg),
                AppButton(
                  key: const Key('tags-browse-confirm'),
                  label: l10n.tagViewMovies,
                  variant: AppButtonVariant.primary,
                  borderRadius: context.appRadius.pillBorder,
                  trailingIcon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: widget.onConfirm,
                ),
                if (widget.onCancel != null) ...<Widget>[
                  SizedBox(width: context.appSpacing.sm),
                  AppTextButton(
                    key: const Key('tags-browse-cancel'),
                    label: l10n.commonCancel,
                    size: AppTextButtonSize.xSmall,
                    onPressed: widget.onCancel,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileActionBar(
    BuildContext context,
    TagSelectionState selection,
    TagSelection notifier,
  ) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return AppGlassSurface(
      key: const Key('tags-browse-action-bar'),
      tone: AppGlassTone.control,
      borderRadius: context.appRadius.lgBorder,
      padding: EdgeInsets.fromLTRB(
        spacing.lg,
        spacing.sm,
        spacing.lg,
        spacing.md,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  l10n.tagSelectedCount(selection.selectedCount),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
                const Spacer(),
                if (selection.selectedCount > 1)
                  _MatchModeToggle(
                    selection: selection,
                    notifier: notifier,
                    mobile: true,
                  ),
                if (widget.onCancel != null) ...<Widget>[
                  SizedBox(width: spacing.sm),
                  AppGlassIconButton(
                    key: const Key('tags-browse-cancel'),
                    tooltip: l10n.commonCancel,
                    icon: Icons.close_rounded,
                    onPressed: widget.onCancel,
                  ),
                ],
              ],
            ),
            SizedBox(height: spacing.sm),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                key: const Key('tags-browse-confirm'),
                label: l10n.tagViewMovies,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.large,
                borderRadius: context.appRadius.pillBorder,
                onPressed: widget.onConfirm,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearQuery() {
    _searchController.clear();
    setState(() => _query = '');
    _searchFocusNode.requestFocus();
  }

  List<TagListItemDto> _tasteTags() {
    final profile = ref.watch(tasteProfileProvider).value;
    if (profile == null ||
        profile.sampleMovieCount < 2 ||
        profile.tags.isEmpty) {
      return const <TagListItemDto>[];
    }
    return profile.tags
        .take(6)
        .map(
          (tag) => TagListItemDto(
            tagId: tag.tagId,
            name: tag.name,
            movieCount: tag.matchedMovieCount,
          ),
        )
        .toList(growable: false);
  }

  List<TagListItemDto> _popularTags(
    List<TagListItemDto> allTags,
    List<TagListItemDto> tasteTags,
  ) {
    final tasteIds = tasteTags.map((tag) => tag.tagId).toSet();
    final sorted = List<TagListItemDto>.of(allTags)
      ..sort((a, b) => b.movieCount.compareTo(a.movieCount));
    return sorted
        .where((tag) => !tasteIds.contains(tag.tagId))
        .take(widget.mobile ? _mobilePopularCount : _desktopPopularCount)
        .toList(growable: false);
  }

  List<TagListItemDto> _searchTags(List<TagListItemDto> allTags) {
    final keyword = _query.trim().toLowerCase();
    return allTags
        .where((tag) => tag.name.toLowerCase().contains(keyword))
        .toList(growable: false);
  }

  int _personalizedTier(TagListItemDto tag) {
    return tag.name.length > 8 ? 2 : 1;
  }

  int _tierFor(int index, TagListItemDto tag) {
    final longName = tag.name.length > 8;
    if (widget.mobile) {
      if (index < 6 && !longName) {
        return 0;
      }
      return index < 18 ? 1 : 2;
    }
    if (index < 6 && !longName) {
      return 0;
    }
    if (index < 16) {
      return 1;
    }
    return index < 32 ? 2 : 3;
  }
}

class _TagCloudItem extends StatelessWidget {
  const _TagCloudItem({
    super.key,
    required this.tag,
    required this.tier,
    required this.personalized,
    required this.selected,
    required this.mobile,
    required this.onTap,
  });

  final TagListItemDto tag;
  final int tier;
  final bool personalized;
  final bool selected;
  final bool mobile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final (size, weight) = _styleFor(tier);
    final tone = selected || personalized
        ? AppTextTone.accent
        : tier <= 1
        ? AppTextTone.primary
        : AppTextTone.secondary;
    return AppInteractiveSurface(
      onTap: onTap,
      semanticLabel: AppLocalizations.of(context).tagSemanticLabel(tag.name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(
          horizontal: spacing.sm,
          vertical: mobile ? spacing.sm : spacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: context.appRadius.pillBorder,
        ),
        child: Text(
          tag.name,
          textAlign: TextAlign.center,
          style: resolveAppTextStyle(
            context,
            size: size,
            weight: weight,
            tone: tone,
          ).copyWith(height: 1.15),
        ),
      ),
    );
  }

  (AppTextSize, AppTextWeight) _styleFor(int tier) {
    if (mobile) {
      return switch (tier) {
        0 => (AppTextSize.s18, AppTextWeight.semibold),
        1 => (AppTextSize.s16, AppTextWeight.medium),
        _ => (AppTextSize.s14, AppTextWeight.regular),
      };
    }
    return switch (tier) {
      0 => (AppTextSize.s20, AppTextWeight.semibold),
      1 => (AppTextSize.s18, AppTextWeight.medium),
      2 => (AppTextSize.s16, AppTextWeight.regular),
      _ => (AppTextSize.s14, AppTextWeight.regular),
    };
  }
}

class _MatchModeToggle extends StatelessWidget {
  const _MatchModeToggle({
    required this.selection,
    required this.notifier,
    required this.mobile,
  });

  final TagSelectionState selection;
  final TagSelection notifier;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!mobile) ...<Widget>[
          Text(
            l10n.tagMatch,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s10,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(width: spacing.xs),
        ],
        AppTextButton(
          key: const Key('tags-browse-match-or'),
          label: TagMatchMode.or.labelWith(l10n),
          size: AppTextButtonSize.xSmall,
          isSelected: selection.matchMode == TagMatchMode.or,
          onPressed: () => notifier.setMatchMode(TagMatchMode.or),
        ),
        SizedBox(width: spacing.xs),
        AppTextButton(
          key: const Key('tags-browse-match-and'),
          label: TagMatchMode.and.labelWith(l10n),
          size: AppTextButtonSize.xSmall,
          isSelected: selection.matchMode == TagMatchMode.and,
          onPressed: () => notifier.setMatchMode(TagMatchMode.and),
        ),
      ],
    );
  }
}
