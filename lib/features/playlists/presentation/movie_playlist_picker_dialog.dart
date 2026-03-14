import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/playlists/data/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/playlists/presentation/create_playlist_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';

Future<void> showMoviePlaylistPickerDialog(
  BuildContext context, {
  required String movieNumber,
  required List<MoviePlaylistSummaryDto> initialPlaylists,
}) {
  return showDialog<void>(
    context: context,
    builder:
        (dialogContext) => MoviePlaylistPickerDialog(
          movieNumber: movieNumber,
          initialPlaylists: initialPlaylists,
        ),
  );
}

class MoviePlaylistPickerDialog extends StatefulWidget {
  const MoviePlaylistPickerDialog({
    super.key,
    required this.movieNumber,
    required this.initialPlaylists,
  });

  final String movieNumber;
  final List<MoviePlaylistSummaryDto> initialPlaylists;

  @override
  State<MoviePlaylistPickerDialog> createState() =>
      _MoviePlaylistPickerDialogState();
}

class _MoviePlaylistPickerDialogState extends State<MoviePlaylistPickerDialog> {
  List<PlaylistDto> _playlists = const <PlaylistDto>[];
  late Set<int> _selectedPlaylistIds;
  final Set<int> _updatingPlaylistIds = <int>{};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedPlaylistIds =
        widget.initialPlaylists.map((playlist) => playlist.id).toSet();
    _load();
  }

  Future<void> _load() async {
    try {
      final playlists = await context.read<PlaylistsApi>().getPlaylists();
      if (!mounted) {
        return;
      }
      setState(() {
        _playlists = playlists
            .where((playlist) => !playlist.isSystem)
            .toList(growable: false);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = apiErrorMessage(error, fallback: '播放列表加载失败');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return Dialog(
      key: const Key('movie-playlist-picker-dialog'),
      backgroundColor: context.appColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: context.appRadius.lgBorder),
      child: SizedBox(
        width: context.appComponentTokens.playlistDialogWidth,
        child: Padding(
          padding: EdgeInsets.all(spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '加入播放列表',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  AppIconButton(
                    key: const Key('movie-playlist-create-button'),
                    onPressed: _createPlaylist,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              SizedBox(height: spacing.lg),
              if (_isLoading)
                const SizedBox(
                  key: Key('movie-playlist-loading'),
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                SizedBox(
                  height: 160,
                  child: AppEmptyState(message: _errorMessage!),
                )
              else if (_playlists.isEmpty)
                const SizedBox(
                  height: 160,
                  child: Center(child: Text('暂无自定义播放列表')),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _playlists.length,
                    separatorBuilder:
                        (context, index) => SizedBox(height: spacing.sm),
                    itemBuilder: (context, index) {
                      final playlist = _playlists[index];
                      final selected = _selectedPlaylistIds.contains(
                        playlist.id,
                      );
                      final isUpdating = _updatingPlaylistIds.contains(
                        playlist.id,
                      );
                      return InkWell(
                        key: Key('movie-playlist-option-${playlist.id}'),
                        borderRadius: context.appRadius.mdBorder,
                        onTap:
                            isUpdating ? null : () => _togglePlaylist(playlist),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: spacing.lg,
                            vertical: spacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: context.appColors.surfaceMuted,
                            borderRadius: context.appRadius.mdBorder,
                            border: Border.all(
                              color:
                                  selected
                                      ? Theme.of(context).colorScheme.primary
                                      : context.appColors.borderSubtle,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (isUpdating)
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                )
                              else
                                Checkbox(
                                  key: Key(
                                    'movie-playlist-checkbox-${playlist.id}',
                                  ),
                                  value: selected,
                                  onChanged:
                                      isUpdating
                                          ? null
                                          : (_) => _togglePlaylist(playlist),
                                ),
                              SizedBox(width: spacing.sm),
                              Expanded(
                                child: Text(
                                  playlist.name,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                              if (playlist.movieCount > 0)
                                Text(
                                  '${playlist.movieCount}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              SizedBox(height: spacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _togglePlaylist(PlaylistDto playlist) async {
    final isSelected = _selectedPlaylistIds.contains(playlist.id);
    setState(() {
      _updatingPlaylistIds.add(playlist.id);
      if (isSelected) {
        _selectedPlaylistIds.remove(playlist.id);
      } else {
        _selectedPlaylistIds.add(playlist.id);
      }
    });

    try {
      if (isSelected) {
        await context.read<PlaylistsApi>().removeMovieFromPlaylist(
          playlistId: playlist.id,
          movieNumber: widget.movieNumber,
        );
      } else {
        await context.read<PlaylistsApi>().addMovieToPlaylist(
          playlistId: playlist.id,
          movieNumber: widget.movieNumber,
        );
      }
    } catch (error) {
      setState(() {
        if (isSelected) {
          _selectedPlaylistIds.add(playlist.id);
        } else {
          _selectedPlaylistIds.remove(playlist.id);
        }
      });
      showToast(
        apiErrorMessage(error, fallback: isSelected ? '移出播放列表失败' : '加入播放列表失败'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingPlaylistIds.remove(playlist.id);
        });
      }
    }
  }

  Future<void> _createPlaylist() async {
    final playlist = await showCreatePlaylistDialog(context);
    if (!mounted || playlist == null) {
      return;
    }
    setState(() {
      _playlists = <PlaylistDto>[playlist, ..._playlists];
    });
    await _togglePlaylist(playlist);
  }
}
