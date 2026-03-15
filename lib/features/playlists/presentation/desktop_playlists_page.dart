import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/playlists/presentation/create_playlist_dialog.dart';
import 'package:sakuramedia/features/playlists/presentation/playlists_overview_controller.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/playlists/playlist_banner_card.dart';

class DesktopPlaylistsPage extends StatefulWidget {
  const DesktopPlaylistsPage({super.key});

  @override
  State<DesktopPlaylistsPage> createState() => _DesktopPlaylistsPageState();
}

class _DesktopPlaylistsPageState extends State<DesktopPlaylistsPage> {
  late final PlaylistsOverviewController _controller;

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
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                  Text('播放列表', style: Theme.of(context).textTheme.titleSmall),
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
              Expanded(
                child:
                    _controller.playlists.isEmpty
                        ? const AppEmptyState(message: '暂无播放列表')
                        : ListView.separated(
                          itemCount: _controller.playlists.length,
                          separatorBuilder:
                              (context, index) =>
                                  SizedBox(height: context.appSpacing.sm),
                          itemBuilder: (context, index) {
                            final playlist = _controller.playlists[index];
                            return PlaylistBannerCard(
                              key: Key('playlist-banner-card-${playlist.id}'),
                              title: playlist.name,
                              coverImageUrl: _controller.coverUrlFor(
                                playlist.id,
                              ),
                              onTap:
                                  () => context.go(
                                    '$desktopPlaylistsPath/${playlist.id}',
                                    extra: desktopPlaylistsPath,
                                  ),
                            );
                          },
                        ),
              ),
            ],
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
