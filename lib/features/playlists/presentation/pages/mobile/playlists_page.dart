import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/data/api/playlists_api.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlists_overview_controller.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/create_playlist_dialog.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/edit_playlist_dialog.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/playlists/playlist_management_card.dart';

class MobilePlaylistsPage extends StatefulWidget {
  const MobilePlaylistsPage({super.key});

  @override
  State<MobilePlaylistsPage> createState() => _MobilePlaylistsPageState();
}

class _MobilePlaylistsPageState extends State<MobilePlaylistsPage> {
  late final PlaylistsOverviewController _controller;

  @override
  void initState() {
    super.initState();
    final api = context.read<PlaylistsApi>();
    _controller = PlaylistsOverviewController(
      fetchPlaylists:
          ({bool includeSystem = true}) =>
              api.getPlaylists(includeSystem: false),
      fetchPlaylistCoverUrl: (playlistId) async {
        final page = await api.getPlaylistMovies(
          playlistId: playlistId,
          pageSize: 1,
        );
        return page.items.firstOrNull?.coverImage?.bestAvailableUrl;
      },
      createPlaylist: api.createPlaylist,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return ColoredBox(
      key: const Key('mobile-settings-playlists'),
      color: colors.surfaceCard,
      child: Column(
        children: [
          Expanded(
            child: AppAdaptiveRefreshScrollView(
              onRefresh: _refreshPlaylists,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.md,
                    spacing.md,
                    spacing.md,
                    spacing.lg,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
                            final customPlaylists = _controller.playlists
                                .where((item) => !item.isSystem)
                                .toList(growable: false);
                            final movieCount = customPlaylists.fold<int>(
                              0,
                              (total, item) => total + item.movieCount,
                            );
                            return AppNoticeCard(
                              key: const Key('mobile-playlists-notice-card'),
                              leadingIcon: Icons.playlist_play_rounded,
                              title: '自定义播放列表管理',
                              description: '这里集中维护可手动管理的播放列表，可继续进入详情查看片单内容。',
                              stats: [
                                AppNoticeStat(
                                  label: '自定义播放列表数',
                                  value: '${customPlaylists.length}',
                                  valueSize: AppTextSize.s18,
                                ),
                                AppNoticeStat(
                                  label: '收录影片总数',
                                  value: '$movieCount',
                                  valueSize: AppTextSize.s18,
                                ),
                              ],
                            );
                          },
                        ),
                        SizedBox(height: spacing.md),
                        _buildContentSection(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(
              spacing.md,
              spacing.md,
              spacing.md,
              spacing.md,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                key: const Key('mobile-playlists-create-button'),
                label: '新建播放列表',
                variant: AppButtonVariant.primary,
                icon: const Icon(Icons.add_rounded),
                onPressed: _handleCreatePlaylist,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSection(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return const _MobilePlaylistsLoadingSection();
        }
        if (_controller.errorMessage != null) {
          return _MobilePlaylistsErrorSection(
            message: _controller.errorMessage!,
            onRetry: _controller.load,
          );
        }

        final playlists =
            _controller.playlists.where((item) => !item.isSystem).toList();
        if (playlists.isEmpty) {
          return const _MobilePlaylistsEmptySection();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: playlists
              .expand(
                (playlist) => <Widget>[
                  PlaylistManagementCard(
                    playlist: playlist,
                    coverImageUrl: _controller.coverUrlFor(playlist.id),
                    layout: PlaylistCardLayout.normal,
                    keyPrefix: 'mobile-playlist',
                    onViewTap: () {
                      MobilePlaylistDetailRouteData(
                        playlistId: playlist.id,
                      ).push(context);
                    },
                    onEditTap: playlist.isMutable
                        ? () => _handleEditPlaylist(playlist)
                        : null,
                    onDeleteTap: playlist.isDeletable
                        ? () => _handleDeletePlaylist(playlist)
                        : null,
                  ),
                  if (playlist != playlists.last)
                    SizedBox(height: context.appSpacing.sm),
                ],
              )
              .toList(growable: false),
        );
      },
    );
  }

  Future<void> _refreshPlaylists() async {
    try {
      await _controller.refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '播放列表加载失败，请稍后重试。'));
    }
  }

  Future<void> _handleCreatePlaylist() async {
    final playlist = await showCreatePlaylistDialog(
      context,
      presentation: CreatePlaylistDialogPresentation.bottomDrawer,
    );
    if (!mounted || playlist == null) {
      return;
    }
    _controller.insertPlaylist(playlist);
    unawaited(_syncPlaylistsInBackground());
    showToast('播放列表已创建');
  }

  Future<void> _handleEditPlaylist(PlaylistDto playlist) async {
    final updated = await showEditPlaylistDialog(
      context,
      playlist: playlist,
      presentation: EditPlaylistDialogPresentation.bottomDrawer,
    );
    if (!mounted || updated == null) {
      return;
    }
    _controller.replacePlaylist(updated);
    unawaited(_syncPlaylistsInBackground());
  }

  Future<void> _handleDeletePlaylist(PlaylistDto playlist) async {
    final api = context.read<PlaylistsApi>();
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除播放列表',
      message: '确认删除播放列表“${playlist.name}”？该操作不可恢复。',
      danger: true,
      confirmLabel: '删除',
      dialogKey: const Key('mobile-playlist-delete-drawer'),
      confirmKey: const Key('mobile-playlist-delete-confirm-button'),
      failureFallback: '删除播放列表失败',
      onConfirm: () => api.deletePlaylist(playlist.id),
    );
    if (!confirmed || !mounted) {
      return;
    }
    _controller.removePlaylist(playlist.id);
    showToast('播放列表已删除');
    unawaited(_syncPlaylistsInBackground());
  }

  Future<void> _syncPlaylistsInBackground() async {
    try {
      await _controller.refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '播放列表加载失败，请稍后重试。'));
    }
  }
}

class _MobilePlaylistsLoadingSection extends StatelessWidget {
  const _MobilePlaylistsLoadingSection();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return Column(
      children: List<Widget>.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : spacing.sm),
          child: _MobilePlaylistSkeletonCard(
            key: Key('mobile-playlist-skeleton-$index'),
          ),
        ),
      ),
    );
  }
}

class _MobilePlaylistSkeletonCard extends StatelessWidget {
  const _MobilePlaylistSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: context.appComponentTokens.playlistBannerHeight,
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: context.appRadius.lgBorder,
              ),
            ),
            SizedBox(height: spacing.md),
            const _PlaylistSkeletonLine(width: 148, height: 16),
            SizedBox(height: spacing.xs),
            const _PlaylistSkeletonLine(width: 72, height: 12),
            SizedBox(height: spacing.xs),
            const _PlaylistSkeletonLine(width: double.infinity, height: 12),
            SizedBox(height: spacing.sm),
            Row(
              children: List<Widget>.generate(
                3,
                (index) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == 2 ? 0 : spacing.sm,
                    ),
                    child: Container(
                      height: context.appComponentTokens.buttonHeightXs,
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: context.appRadius.smBorder,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistSkeletonLine extends StatelessWidget {
  const _PlaylistSkeletonLine({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.smBorder,
      ),
    );
  }
}

class _MobilePlaylistsErrorSection extends StatelessWidget {
  const _MobilePlaylistsErrorSection({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return Container(
      key: const Key('mobile-playlists-error-state'),
      padding: EdgeInsets.all(spacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppEmptyState(message: '播放列表加载失败'),
          SizedBox(height: spacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.md),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              key: const Key('mobile-playlists-retry-button'),
              label: '重试',
              variant: AppButtonVariant.primary,
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobilePlaylistsEmptySection extends StatelessWidget {
  const _MobilePlaylistsEmptySection();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mobile-playlists-empty-state'),
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.md,
        vertical: context.appSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: const AppEmptyState(message: '还没有自定义播放列表'),
    );
  }
}
