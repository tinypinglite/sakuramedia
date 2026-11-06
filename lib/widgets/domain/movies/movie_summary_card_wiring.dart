import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_subscription_toggle_provider.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_card.dart';

/// [MovieSummaryCard] 的接线参数（grid / sliver / rail 三个容器同源）。
///
/// 三个容器此前各抄一份 13 个参数的回调接线，改一处卡片交互要同步四处；
/// 这里收口成一份，容器只负责布局（网格 / sliver / 横向 rail）。
class MovieSummaryCardWiring {
  const MovieSummaryCardWiring({
    required this.onMovieTap,
    required this.onMovieLongPress,
    required this.onMovieMenuRequest,
    required this.onMovieSubscriptionTap,
    required this.onMovieToggleCollectionType,
    required this.onMovieBlacklist,
    required this.isMovieSubscriptionUpdating,
    required this.useDefaultSubscriptionActions,
    required this.secondaryLabelForMovie,
    this.trailingLabelForMovie,
  });

  final ValueChanged<MovieListItemDto>? onMovieTap;
  final ValueChanged<MovieListItemDto>? onMovieLongPress;
  final void Function(MovieListItemDto movie, Offset globalPosition)?
  onMovieMenuRequest;
  final ValueChanged<MovieListItemDto>? onMovieSubscriptionTap;
  final ValueChanged<MovieListItemDto>? onMovieToggleCollectionType;
  final ValueChanged<MovieListItemDto>? onMovieBlacklist;
  final bool Function(MovieListItemDto movie)? isMovieSubscriptionUpdating;

  /// 未传自定义订阅回调时，接入跨列表复用的默认订阅动作。
  final bool useDefaultSubscriptionActions;
  final String? Function(MovieListItemDto movie)? secondaryLabelForMovie;

  /// 收起态番号行右侧文案（如「总分 4.0」）；null 时不显示。
  final String? Function(MovieListItemDto movie)? trailingLabelForMovie;

  /// watch 默认订阅动作的进行中集合；不启用默认动作时返回空集。
  Set<String> _watchUpdatingMovieNumbers(WidgetRef ref) =>
      _usesDefaultSubscriptionActions
      ? ref.watch(movieSubscriptionToggleProvider)
      : const <String>{};

  /// 未传自定义订阅回调时，接入跨列表复用的默认订阅动作。
  bool get _usesDefaultSubscriptionActions =>
      useDefaultSubscriptionActions && onMovieSubscriptionTap == null;

  MovieSummaryCard build(
    BuildContext context,
    WidgetRef ref,
    MovieListItemDto movie, {
    bool selectionMode = false,
    bool isSelected = false,
    void Function(bool selected)? onSelectedChanged,
  }) {
    final updatingMovieNumbers = _watchUpdatingMovieNumbers(ref);
    return MovieSummaryCard(
      movie: movie,
      onTap: onMovieTap == null ? null : () => onMovieTap!(movie),
      onLongPress: onMovieLongPress == null
          ? null
          : () => onMovieLongPress!(movie),
      onRequestMenu: onMovieMenuRequest == null
          ? null
          : (globalPosition) => onMovieMenuRequest!(movie, globalPosition),
      onSubscriptionTap: onMovieSubscriptionTap != null
          ? () => onMovieSubscriptionTap!(movie)
          : _usesDefaultSubscriptionActions
          ? () =>
                unawaited(_toggleDefaultMovieSubscription(ref, context, movie))
          : null,
      onToggleCollectionType: onMovieToggleCollectionType == null
          ? null
          : () => onMovieToggleCollectionType!(movie),
      onBlacklist: onMovieBlacklist == null
          ? null
          : () => onMovieBlacklist!(movie),
      isSubscriptionUpdating:
          isMovieSubscriptionUpdating?.call(movie) ??
          updatingMovieNumbers.contains(movie.movieNumber),
      secondaryLabel: secondaryLabelForMovie?.call(movie),
      trailingLabel: trailingLabelForMovie?.call(movie),
      selectionMode: selectionMode,
      isSelected: isSelected,
      onSelectedChanged: onSelectedChanged,
    );
  }
}

Future<void> _toggleDefaultMovieSubscription(
  WidgetRef ref,
  BuildContext context,
  MovieListItemDto movie,
) async {
  final result = await ref
      .read(movieSubscriptionToggleProvider.notifier)
      .toggle(movieNumber: movie.movieNumber, isSubscribed: movie.isSubscribed);
  if (context.mounted) {
    showMovieSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
  }
}
