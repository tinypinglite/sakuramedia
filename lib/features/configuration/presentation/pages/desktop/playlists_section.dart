import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_scope.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_state.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/create_playlist_dialog.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/edit_playlist_dialog.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_skeleton.dart';
import 'package:sakuramedia/widgets/domain/playlists/playlist_management_card.dart';

class PlaylistsSection extends ConsumerStatefulWidget {
  const PlaylistsSection({super.key, required this.active});

  final bool active;

  @override
  ConsumerState<PlaylistsSection> createState() => _PlaylistsSectionState();
}

class _PlaylistsSectionState extends ConsumerState<PlaylistsSection> {
  // configuration 内的播放列表管理 section：不持久化顺序 + 排除系统列表。
  static const PlaylistsOverviewScope _scope = PlaylistsOverviewScope(
    orderScopeKey: null,
    includeSystem: false,
  );

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _tryLoadIfActive();
  }

  @override
  void didUpdateWidget(covariant PlaylistsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _tryLoadIfActive();
  }

  /// IndexedStack 懒加载：只有 active 后才首次订阅 provider，避免所有 tab
  /// 一起发请求。首次订阅由 build 时 `ref.watch` 触发。
  void _tryLoadIfActive() {
    if (!widget.active || _initialized) {
      return;
    }
    _initialized = true;
  }

  Future<void> _createPlaylist() async {
    final created = await showCreatePlaylistDialog(context);
    if (!mounted || created == null) {
      return;
    }
    ref
        .read(playlistsOverviewProvider(_scope).notifier)
        .insertPlaylist(created);
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
    ref
        .read(playlistsOverviewProvider(_scope).notifier)
        .replacePlaylist(updated);
    unawaited(_syncInBackground());
  }

  Future<void> _deletePlaylist(PlaylistDto playlist) async {
    if (!playlist.isDeletable) {
      return;
    }
    final api = ref.read(playlistsApiProvider);
    final ok = await showAppConfigDeleteConfirm(
      context: context,
      title: '删除播放列表',
      message: '确认删除播放列表“${playlist.name}”？该操作不可恢复。',
      onDelete: () => api.deletePlaylist(playlist.id),
      successToast: '播放列表已删除',
      failureFallback: '删除播放列表失败',
    );
    if (ok && mounted) {
      ref
          .read(playlistsOverviewProvider(_scope).notifier)
          .removePlaylist(playlist.id);
      unawaited(_syncInBackground());
    }
  }

  void _viewPlaylist(PlaylistDto playlist) {
    context.pushDesktopPlaylistDetail(playlistId: playlist.id);
  }

  Future<void> _syncInBackground() async {
    try {
      await ref.read(playlistsOverviewProvider(_scope).notifier).refresh();
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
    final async = ref.watch(playlistsOverviewProvider(_scope));
    return Builder(
      builder: (context) {
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
            _buildNoticeCard(context, async.value?.playlists ?? const []),
            SizedBox(height: spacing.md),
            _buildContent(context, async),
          ],
        );
      },
    );
  }

  Widget _buildNoticeCard(
    BuildContext context,
    List<PlaylistDto> allPlaylists,
  ) {
    final customPlaylists =
        allPlaylists.where((item) => !item.isSystem).toList();
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

  Widget _buildContent(
    BuildContext context,
    AsyncValue<PlaylistsOverviewState> async,
  ) {
    final state = async.value;
    final allPlaylists = state?.playlists ?? const <PlaylistDto>[];
    if (async.isLoading && allPlaylists.isEmpty) {
      return const AppSectionSkeleton(lineCount: 4);
    }
    if (async.hasError && allPlaylists.isEmpty) {
      return AppEmptyState(
        message: apiErrorMessage(async.error!, fallback: '播放列表加载失败，请稍后重试'),
        onRetry:
            () => unawaited(
              ref.read(playlistsOverviewProvider(_scope).notifier).refresh(),
            ),
        retryLabel: '重试',
      );
    }
    final playlists = allPlaylists.where((item) => !item.isSystem).toList();
    if (playlists.isEmpty) {
      return const AppEmptyState(message: '还没有自定义播放列表');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.appSpacing;
        const targetWidth = 420.0;
        final available = constraints.maxWidth;
        final columns =
            available < targetWidth * 1.6
                ? 1
                : ((available + spacing.md) / (targetWidth + spacing.md))
                    .floor()
                    .clamp(1, 3);
        final cardWidth =
            columns == 1
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
                  coverImageUrl: state?.coverUrlFor(playlist.id),
                  layout: PlaylistCardLayout.dense,
                  keyPrefix: 'desktop-playlist',
                  onViewTap: () => _viewPlaylist(playlist),
                  onEditTap:
                      playlist.isMutable ? () => _editPlaylist(playlist) : null,
                  onDeleteTap:
                      playlist.isDeletable
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
