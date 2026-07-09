import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/features/playlists/data/api/playlists_api.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlists_overview_controller.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/create_playlist_dialog.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/edit_playlist_dialog.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_skeleton.dart';
import 'package:sakuramedia/widgets/playlists/playlist_management_card.dart';

class PlaylistsSection extends StatefulWidget {
  const PlaylistsSection({super.key, required this.active});

  final bool active;

  @override
  State<PlaylistsSection> createState() => _PlaylistsSectionState();
}

class _PlaylistsSectionState extends State<PlaylistsSection> {
  late final PlaylistsOverviewController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    final api = context.read<PlaylistsApi>();
    _controller = PlaylistsOverviewController(
      fetchPlaylists: ({bool includeSystem = true}) =>
          api.getPlaylists(includeSystem: false),
      fetchPlaylistCoverUrl: (playlistId) async {
        final page = await api.getPlaylistMovies(
          playlistId: playlistId,
          pageSize: 1,
        );
        return page.items.firstOrNull?.coverImage?.bestAvailableUrl;
      },
      createPlaylist: api.createPlaylist,
    );
    _tryLoadIfActive();
  }

  @override
  void didUpdateWidget(covariant PlaylistsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _tryLoadIfActive();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tryLoadIfActive() {
    if (!widget.active || _initialized) {
      return;
    }
    _initialized = true;
    unawaited(_controller.load());
  }

  Future<void> _createPlaylist() async {
    final created = await showCreatePlaylistDialog(context);
    if (!mounted || created == null) {
      return;
    }
    _controller.insertPlaylist(created);
    showToast('播放列表已创建');
    unawaited(_syncInBackground());
  }

  Future<void> _editPlaylist(PlaylistDto playlist) async {
    if (!playlist.isMutable) {
      return;
    }
    final updated = await showEditPlaylistDialog(
      context,
      playlist: playlist,
      presentation: EditPlaylistDialogPresentation.dialog,
    );
    if (!mounted || updated == null) {
      return;
    }
    _controller.replacePlaylist(updated);
    unawaited(_syncInBackground());
  }

  Future<void> _deletePlaylist(PlaylistDto playlist) async {
    if (!playlist.isDeletable) {
      return;
    }
    final api = context.read<PlaylistsApi>();
    final ok = await showAppConfigDeleteConfirm(
      context: context,
      title: '删除播放列表',
      message: '确认删除播放列表“${playlist.name}”？该操作不可恢复。',
      onDelete: () => api.deletePlaylist(playlist.id),
      successToast: '播放列表已删除',
      failureFallback: '删除播放列表失败',
    );
    if (ok && mounted) {
      _controller.removePlaylist(playlist.id);
      unawaited(_syncInBackground());
    }
  }

  void _viewPlaylist(PlaylistDto playlist) {
    context.pushDesktopPlaylistDetail(playlistId: playlist.id);
  }

  Future<void> _syncInBackground() async {
    try {
      await _controller.refresh();
    } catch (_) {
      // 对账失败静默：本地已乐观更新，下一次进入时自然刷新。
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized && !widget.active) {
      return const SizedBox.shrink();
    }
    final spacing = context.appSpacing;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '自定义播放列表',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ),
                AppButton(
                  key: const Key('configuration-playlist-create-button'),
                  onPressed: _createPlaylist,
                  icon: const Icon(Icons.add_rounded),
                  label: '新建播放列表',
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.primary,
                ),
              ],
            ),
            SizedBox(height: spacing.md),
            _buildNoticeCard(context),
            SizedBox(height: spacing.md),
            _buildContent(context),
          ],
        );
      },
    );
  }

  Widget _buildNoticeCard(BuildContext context) {
    final customPlaylists =
        _controller.playlists.where((item) => !item.isSystem).toList();
    final movieCount = customPlaylists.fold<int>(
      0,
      (total, item) => total + item.movieCount,
    );
    return AppNoticeCard(
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
  }

  Widget _buildContent(BuildContext context) {
    if (_controller.isLoading && _controller.playlists.isEmpty) {
      return const AppSectionSkeleton(lineCount: 4);
    }
    if (_controller.errorMessage != null && _controller.playlists.isEmpty) {
      return AppEmptyState(
        message: _controller.errorMessage!,
        onRetry: () => unawaited(_controller.load()),
        retryLabel: '重试',
      );
    }
    final playlists =
        _controller.playlists.where((item) => !item.isSystem).toList();
    if (playlists.isEmpty) {
      return const AppEmptyState(message: '还没有自定义播放列表');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.appSpacing;
        const targetWidth = 420.0;
        final available = constraints.maxWidth;
        final columns = available < targetWidth * 1.6
            ? 1
            : ((available + spacing.md) / (targetWidth + spacing.md))
                .floor()
                .clamp(1, 3);
        final cardWidth = columns == 1
            ? available
            : (available - spacing.md * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing.md,
          runSpacing: spacing.md,
          children: [
            for (final playlist in playlists)
              SizedBox(
                width: cardWidth,
                child: PlaylistManagementCard(
                  playlist: playlist,
                  coverImageUrl: _controller.coverUrlFor(playlist.id),
                  layout: PlaylistCardLayout.dense,
                  keyPrefix: 'desktop-playlist',
                  onViewTap: () => _viewPlaylist(playlist),
                  onEditTap: playlist.isMutable
                      ? () => _editPlaylist(playlist)
                      : null,
                  onDeleteTap: playlist.isDeletable
                      ? () => _deletePlaylist(playlist)
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}
