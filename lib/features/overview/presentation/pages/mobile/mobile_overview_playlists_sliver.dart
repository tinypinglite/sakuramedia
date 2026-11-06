import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_scope.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/domain/playlists/playlist_banner_card.dart';
import 'package:skeletonizer/skeletonizer.dart';

class MobileOverviewPlaylistsSliver extends ConsumerWidget {
  const MobileOverviewPlaylistsSliver({super.key, required this.scope});

  final PlaylistsOverviewScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(
      playlistsOverviewProvider(scope).select(selectPlaylistsOverview),
    );
    if (overview.isLoading) {
      return SliverToBoxAdapter(child: _buildSkeleton(context));
    }
    if (overview.error case final error?) {
      final l10n = AppLocalizations.of(context);
      return SliverToBoxAdapter(
        child: AppEmptyState(
          message: apiErrorMessage(
            error,
            fallback: l10n.overviewPlaylistsLoadFailed,
            l10n: l10n,
          ),
        ),
      );
    }
    final playlists = overview.playlists;
    if (playlists.isEmpty) {
      return SliverToBoxAdapter(
        child: AppEmptyState(
          message: AppLocalizations.of(context).overviewNoPlaylists,
        ),
      );
    }

    return SliverReorderableList(
      key: const Key('mobile-overview-playlists-list'),
      itemCount: playlists.length,
      findChildIndexCallback: (key) {
        if (key is! ValueKey<int>) {
          return null;
        }
        final index = playlists.indexWhere(
          (playlist) => playlist.id == key.value,
        );
        return index < 0 ? null : index;
      },
      onReorderItem: ref
          .read(playlistsOverviewProvider(scope).notifier)
          .reorderPlaylists,
      onReorderStart: _handleReorderStart,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return ReorderableDelayedDragStartListener(
          key: ValueKey<int>(playlist.id),
          index: index,
          child: Padding(
            padding: EdgeInsets.only(bottom: context.appSpacing.sm),
            child: _OverviewPlaylistBanner(scope: scope, playlist: playlist),
          ),
        );
      },
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final spacing = context.appSpacing;
    // loading 用占位播放列表渲染真实横幅，由 [AppSkeletonizer] 灰化。
    return AppSkeletonizer(
      enabled: true,
      child: Column(
        children: [
          for (var index = 0; index < 6; index++) ...[
            if (index > 0) SizedBox(height: spacing.sm),
            PlaylistBannerCard(title: BoneMock.words(2), coverImageUrl: null),
          ],
        ],
      ),
    );
  }

  void _handleReorderStart(int _) {
    unawaited(
      HapticFeedback.mediumImpact().catchError((Object _) {
        return;
      }),
    );
  }
}

class _OverviewPlaylistBanner extends ConsumerWidget {
  const _OverviewPlaylistBanner({required this.scope, required this.playlist});

  final PlaylistsOverviewScope scope;
  final PlaylistDto playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverImageUrl = ref.watch(
      playlistsOverviewProvider(
        scope,
      ).select((async) => async.value?.coverUrlFor(playlist.id)),
    );
    return PlaylistBannerCard(
      key: Key('mobile-overview-playlist-${playlist.id}'),
      title: playlist.name,
      coverImageUrl: coverImageUrl,
      onTap: () =>
          MobileRoutes.playlistDetail(playlistId: playlist.id).push(context),
    );
  }
}
