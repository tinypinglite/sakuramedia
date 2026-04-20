import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/playlists/data/playlist_order_store.dart';
import 'package:sakuramedia/features/playlists/presentation/create_playlist_dialog.dart';
import 'package:sakuramedia/features/playlists/presentation/playlists_overview_controller.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/playlists/playlist_banner_card.dart';

class DesktopPlaylistsPage extends StatefulWidget {
  const DesktopPlaylistsPage({
    super.key,
    this.playlistOrderStore = const SharedPreferencesPlaylistOrderStore(),
  });

  final PlaylistOrderStore playlistOrderStore;

  @override
  State<DesktopPlaylistsPage> createState() => _DesktopPlaylistsPageState();
}

class _DesktopPlaylistsPageState extends State<DesktopPlaylistsPage> {
  late final PlaylistsOverviewController _controller;
  int? _hoveredPlaylistId;

  @override
  void initState() {
    super.initState();
    final api = context.read<PlaylistsApi>();
    _controller = PlaylistsOverviewController(
      fetchPlaylists: api.getPlaylists,
      fetchPlaylistCoverUrl: (playlistId) async {
        final page = await api.getPlaylistMovies(
          playlistId: playlistId,
          pageSize: 1,
        );
        return page.items.firstOrNull?.coverImage?.bestAvailableUrl;
      },
      createPlaylist: api.createPlaylist,
      playlistOrderStore: widget.playlistOrderStore,
      orderScopeKey: context.read<SessionStore>().baseUrl,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setHoveredPlaylistId(int? playlistId) {
    if (_hoveredPlaylistId == playlistId) {
      return;
    }
    setState(() => _hoveredPlaylistId = playlistId);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return const SizedBox.expand(
            child: Center(
              child: SizedBox(
                key: Key('playlists-page-loading'),
                width: 40,
                height: 40,
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (_controller.errorMessage != null) {
          return AppEmptyState(message: _controller.errorMessage!);
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
                      size: AppTextSize.s18,
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
              Expanded(child: _buildPlaylistsList(context)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaylistsList(BuildContext context) {
    final playlists = _controller.playlists;
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
            coverImageUrl: _controller.coverUrlFor(playlist.id),
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
      onReorder: _controller.reorderPlaylists,
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
                  coverImageUrl: _controller.coverUrlFor(playlist.id),
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
    _controller.insertPlaylist(playlist);
    if (!mounted) {
      return;
    }
    showToast('已创建播放列表');
  }
}
