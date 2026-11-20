import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_tags_provider.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_chip.dart';
import 'package:sakuramedia/widgets/domain/tags/app_tag_match_mode_toggle.dart';

/// 影片列表与女优详情作品区共用的「媒体文件标签」筛选分节。
///
/// 选中状态完全由入参 [filter] 决定：调用方（桌面筛选面板、移动筛选抽屉）
/// 持有筛选状态，组件不另存一份副本，避免两边分叉。
class MediaTagFilterSection extends ConsumerWidget {
  const MediaTagFilterSection({
    super.key,
    required this.mediaTagIds,
    required this.mediaTagMatch,
    required this.onChanged,
    this.selectionStyle = AppFilterChipSelectionStyle.neutral,
  });

  final List<int> mediaTagIds;
  final TagMatchMode mediaTagMatch;
  final void Function(List<int> tagIds, TagMatchMode matchMode) onChanged;

  /// 选中 chips 的配色；卡片表单里用 [AppFilterChipSelectionStyle.accent]。
  final AppFilterChipSelectionStyle selectionStyle;

  void _toggleTag(int tagId) {
    final next = List<int>.of(mediaTagIds);
    if (!next.remove(tagId)) {
      next.add(tagId);
    }
    onChanged(next, mediaTagMatch);
  }

  void _changeMatchMode(TagMatchMode matchMode) {
    onChanged(mediaTagIds, matchMode);
  }

  void _clear() {
    onChanged(const <int>[], mediaTagMatch);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final tagsAsync = ref.watch(mediaTagsProvider);
    final tags = tagsAsync.value ?? const [];

    return Column(
      key: const Key('movie-media-tag-filter-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.movieMediaTagFilterTitle,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.medium,
                  tone: AppTextTone.secondary,
                ),
              ),
            ),
            if (mediaTagIds.isNotEmpty)
              AppTextButton(
                key: const Key('movie-media-tag-filter-clear'),
                label: l10n.movieMediaTagFilterClear,
                size: AppTextButtonSize.xSmall,
                onPressed: _clear,
              ),
          ],
        ),
        SizedBox(height: spacing.sm),
        if (tagsAsync.isLoading && tagsAsync.value == null)
          const AppInlineSpinner()
        else if (tagsAsync.hasError && tagsAsync.value == null)
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.mediaTagsLoadFailedTitle,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.error,
                  ),
                ),
              ),
              AppTextButton(
                key: const Key('movie-media-tag-filter-retry'),
                label: l10n.commonRetry,
                size: AppTextButtonSize.xSmall,
                onPressed: () => ref.read(mediaTagsProvider.notifier).reload(),
              ),
            ],
          )
        else if (tags.isEmpty)
          Text(
            l10n.mediaTagsEmpty,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          )
        else
          Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            children: [
              for (final tag in tags)
                AppFilterChip(
                  key: Key('movie-media-tag-filter-${tag.id}'),
                  label: tag.name,
                  selected: mediaTagIds.contains(tag.id),
                  selectionStyle: selectionStyle,
                  onPressed: () => _toggleTag(tag.id),
                ),
            ],
          ),
        if (mediaTagIds.length > 1) ...[
          SizedBox(height: spacing.md),
          Row(
            children: [
              Text(
                l10n.movieMediaTagFilterSelectedCount(mediaTagIds.length),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.secondary,
                ),
              ),
              const Spacer(),
              AppTagMatchModeToggle(
                matchMode: mediaTagMatch,
                buttonKeyPrefix: 'movie-media-tag-match',
                onChanged: _changeMatchMode,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
