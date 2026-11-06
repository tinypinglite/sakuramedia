import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/player/movie_subtitle_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_pill_wrap.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';

class MovieSubtitleSection extends StatelessWidget {
  const MovieSubtitleSection({
    super.key,
    required this.items,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.onOpenSubtitle,
  });

  final List<MovieSubtitleItemDto> items;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function()? onRetry;
  final Future<void> Function(MovieSubtitleItemDto item)? onOpenSubtitle;

  @override
  Widget build(BuildContext context) {
    if (isLoading && items.isEmpty) {
      // loading 用占位字幕渲染真实药丸行，由 [AppSkeletonizer] 灰化；
      // 刷新保留旧字幕时直接显示旧数据。
      return AppSkeletonizer(
        enabled: true,
        child: _buildPills(context, movieSubtitlePlaceholders()),
      );
    }

    final error = errorMessage?.trim();
    if (error != null && error.isNotEmpty) {
      return AppErrorState(
        key: const Key('movie-subtitles-error'),
        icon: Icons.subtitles_outlined,
        title: AppLocalizations.of(context).movieWidgetSubtitleListLoadFailed,
        message: error,
        onRetry: onRetry == null ? null : () => unawaited(onRetry!()),
        retryKey: const Key('movie-subtitles-retry'),
        variant: AppStatePanelVariant.section,
      );
    }

    if (items.isEmpty) {
      return AppEmptyState(
        key: const Key('movie-subtitles-empty'),
        icon: Icons.subtitles_outlined,
        message: AppLocalizations.of(context).movieWidgetNoSubtitles,
      );
    }

    return _buildPills(context, items);
  }

  Widget _buildPills(BuildContext context, List<MovieSubtitleItemDto> pills) {
    final l10n = AppLocalizations.of(context);
    return MovieDetailPillWrap(
      key: const Key('movie-subtitles-list'),
      emptyMessage: l10n.movieWidgetNoSubtitles,
      items: [
        for (final item in pills)
          MovieDetailPillItem(
            key: Key('movie-subtitle-item-${item.subtitleId}'),
            label: item.displayName(l10n),
            onTap: onOpenSubtitle == null
                ? null
                : () => unawaited(onOpenSubtitle!(item)),
          ),
      ],
    );
  }
}
