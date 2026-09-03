import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_scope.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/create_playlist_dialog.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/domain/playlists/playlist_banner_card.dart';

class DesktopPlaylistsPage extends ConsumerStatefulWidget {
  const DesktopPlaylistsPage({super.key});

  @override
  ConsumerState<DesktopPlaylistsPage> createState() =>
      _DesktopPlaylistsPageState();
}

class _DesktopPlaylistsPageState extends ConsumerState<DesktopPlaylistsPage> {
  int? _hoveredPlaylistId;
  late final PlaylistsOverviewScope _scope;

  @override
  void initState() {
    super.initState();
    _scope = PlaylistsOverviewScope(
      orderScopeKey: ref.read(sessionStoreProvider).baseUrl,
      // 桌面 playlists 独立页展示全部（含系统列表）。
    );
  }

  void _setHoveredPlaylistId(int? playlistId) {
    if (_hoveredPlaylistId == playlistId) {
      return;
    }
    setState(() => _hoveredPlaylistId = playlistId);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(playlistsOverviewProvider(_scope));
    final notifier = ref.read(playlistsOverviewProvider(_scope).notifier);

    return AppPageRefreshScope(
      onRefresh: notifier.refresh,
      child: Builder(
        builder: (context) {
          if (async.isLoading && async.value == null) {
            return const _DesktopPlaylistsLoadingState();
          }
          if (async.hasError && async.value == null) {
            return AppEmptyState(
              message: apiErrorMessage(
                async.error!,
                fallback: '播放列表暂时无法加载，请稍后重试',
              ),
            );
          }
          final state = async.value;
          if (state == null) {
            return const SizedBox.shrink();
          }
          return ColoredBox(
            color: context.appColors.surfaceElevated,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '播放列表',
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        weight: AppTextWeight.semibold,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    const Spacer(),
                    AppButton(
                      key: const Key('playlists-create-button'),
                      label: '新建播放列表',
                      variant: AppButtonVariant.primary,
                      onPressed: _openCreateDialog,
                      size: AppButtonSize.small,
                    ),
                  ],
                ),
                SizedBox(height: context.appSpacing.lg),
                Expanded(child: _buildPlaylistsList(context, state, notifier)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistsList(
    BuildContext context,
    dynamic state,
    dynamic notifier,
  ) {
    final playlists = state.playlists;
    if (playlists.isEmpty) {
      return const AppEmptyState(message: '暂无播放列表');
    }

    if (playlists.length < 2) {
      final playlist = playlists.single;
      return ListView(
        children: [
          PlaylistBannerCard(
            key: Key('playlist-banner-card-${playlist.id}'),
            title: playlist.name,
            coverImageUrl: state.coverUrlFor(playlist.id),
            onTap:
                () => context.pushDesktopPlaylistDetail(
                  playlistId: playlist.id,
                  fallbackPath: desktopPlaylistsPath,
                ),
          ),
        ],
      );
    }

    return ReorderableListView.builder(
      key: const Key('desktop-playlists-reorderable-list'),
      buildDefaultDragHandles: false,
      itemCount: playlists.length,
      onReorder: notifier.reorderPlaylists,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        final isHovered = _hoveredPlaylistId == playlist.id;
        return Padding(
          key: ValueKey<int>(playlist.id),
          padding: EdgeInsets.only(bottom: context.appSpacing.sm),
          child: MouseRegion(
            onEnter: (_) => _setHoveredPlaylistId(playlist.id),
            onExit: (_) {
              if (_hoveredPlaylistId == playlist.id) {
                _setHoveredPlaylistId(null);
              }
            },
            child: Stack(
              children: [
                PlaylistBannerCard(
                  key: Key('playlist-banner-card-${playlist.id}'),
                  title: playlist.name,
                  coverImageUrl: state.coverUrlFor(playlist.id),
                  onTap:
                      () => context.pushDesktopPlaylistDetail(
                        playlistId: playlist.id,
                        fallbackPath: desktopPlaylistsPath,
                      ),
                ),
                Positioned(
                  right: context.appSpacing.sm,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IgnorePointer(
                      ignoring: !isHovered,
                      child: Visibility(
                        visible: isHovered,
                        child: ReorderableDragStartListener(
                          index: index,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: context.appColors.surfaceCard.withValues(
                                  alpha: 0.92,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.appColors.borderSubtle,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(context.appSpacing.xs),
                                child: Icon(
                                  Icons.unfold_more_rounded,
                                  key: Key(
                                    'playlist-reorder-handle-${playlist.id}',
                                  ),
                                  size: context.appComponentTokens.iconSizeMd,
                                  color: context.appTextPalette.primary,
                                ),
                              ),
                            ),
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
      },
    );
  }

  Future<void> _openCreateDialog() async {
    final playlist = await showCreatePlaylistDialog(context);
    if (!mounted || playlist == null) {
      return;
    }
    ref
        .read(playlistsOverviewProvider(_scope).notifier)
        .insertPlaylist(playlist);
    if (!mounted) {
      return;
    }
    showToast('已创建播放列表');
  }
}

class _DesktopPlaylistsLoadingState extends StatelessWidget {
  const _DesktopPlaylistsLoadingState();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return ColoredBox(
      color: context.appColors.surfaceElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppSkeletonBlock(width: 88, height: 22),
              const Spacer(),
              AppSkeletonBlock(
                width: 108,
                height: context.appComponentTokens.buttonHeightSm,
                radius: context.appRadius.pillBorder,
              ),
            ],
          ),
          SizedBox(height: spacing.lg),
          Expanded(
            child: ListView.separated(
              key: const Key('playlists-page-loading'),
              itemCount: 3,
              separatorBuilder: (_, _) => SizedBox(height: spacing.sm),
              itemBuilder: (_, _) => const PlaylistBannerCardSkeleton(),
            ),
          ),
        ],
      ),
    );
  }
}
