import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_subscription_toggle_provider.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_subscription_toggle_provider.dart';
import 'package:sakuramedia/features/recent_views/data/dto/recent_view_dto.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_summary_card.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_card.dart';

/// 「最近浏览」条目卡：影片 / 女优都直接复用全站标准海报卡。
///
/// 订阅心走跨列表的标准 toggle provider，历史顺序不因订阅状态变化而增删；
/// 影片卡保留右键操作菜单。
class RecentViewCard extends ConsumerWidget {
  const RecentViewCard({
    super.key,
    required this.entry,
    required this.onMovieTap,
    required this.onActorTap,
  });

  final RecentViewEntryDto entry;
  final ValueChanged<String> onMovieTap;
  final ValueChanged<int> onActorTap;

  static Key keyFor(RecentViewEntryDto entry) {
    final movie = entry.movie;
    if (movie != null) {
      return Key('recent-view-card-movie-${movie.movieNumber}');
    }
    return Key('recent-view-card-actor-${entry.actor!.id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movie = entry.movie;
    if (movie != null) {
      return MovieSummaryCard(
        key: keyFor(entry),
        movie: movie,
        onTap: () => onMovieTap(movie.movieNumber),
        onRequestMenu: (globalPosition) => requestMovieCollectionMenu(
          context,
          movie.movieNumber,
          globalPosition,
          isSubscribed: movie.isSubscribed,
        ),
        onSubscriptionTap: () =>
            unawaited(_toggleMovieSubscription(ref, context, movie)),
        isSubscriptionUpdating: ref
            .watch(movieSubscriptionToggleProvider)
            .contains(movie.movieNumber),
      );
    }
    final actor = entry.actor!;
    return ActorSummaryCard(
      key: keyFor(entry),
      actor: actor,
      onTap: () => onActorTap(actor.id),
      onSubscriptionTap: () =>
          unawaited(_toggleActorSubscription(ref, context, actor)),
      isSubscriptionUpdating: ref
          .watch(actorSubscriptionToggleProvider)
          .contains(actor.id),
    );
  }
}

Future<void> _toggleMovieSubscription(
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

Future<void> _toggleActorSubscription(
  WidgetRef ref,
  BuildContext context,
  ActorListItemDto actor,
) async {
  final result = await ref
      .read(actorSubscriptionToggleProvider.notifier)
      .toggle(actorId: actor.id, isSubscribed: actor.isSubscribed);
  if (context.mounted) {
    showActorSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
  }
}
