import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/playlists/data/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/playlists/presentation/create_playlist_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';

enum MoviePlaylistPickerPresentation { dialog, bottomDrawer }

Future<void> showMoviePlaylistPickerDialog(
  BuildContext context, {
  required String movieNumber,
  required List<MoviePlaylistSummaryDto> initialPlaylists,
  MoviePlaylistPickerPresentation presentation =
      MoviePlaylistPickerPresentation.dialog,
}) {
  switch (presentation) {
    case MoviePlaylistPickerPresentation.dialog:
      return showDialog<void>(
        context: context,
        builder:
            (dialogContext) => MoviePlaylistPickerDialog(
              movieNumber: movieNumber,
              initialPlaylists: initialPlaylists,
              presentation: MoviePlaylistPickerPresentation.dialog,
            ),
      );
    case MoviePlaylistPickerPresentation.bottomDrawer:
      return showAppBottomDrawer<void>(
        context: context,
        drawerKey: const Key('movie-playlist-picker-bottom-sheet'),
        heightFactor: 0.4,
        // maxHeightFactor: 0.4,
        builder:
            (sheetContext) => MoviePlaylistPickerDialog(
              movieNumber: movieNumber,
              initialPlaylists: initialPlaylists,
              presentation: MoviePlaylistPickerPresentation.bottomDrawer,
            ),
      );
  }
}

class MoviePlaylistPickerDialog extends StatefulWidget {
  const MoviePlaylistPickerDialog({
    super.key,
    required this.movieNumber,
    required this.initialPlaylists,
    this.presentation = MoviePlaylistPickerPresentation.dialog,
  });

  final String movieNumber;
  final List<MoviePlaylistSummaryDto> initialPlaylists;
  final MoviePlaylistPickerPresentation presentation;

  @override
  State<MoviePlaylistPickerDialog> createState() =>
      _MoviePlaylistPickerDialogState();
}

class _MoviePlaylistPickerDialogState extends State<MoviePlaylistPickerDialog> {
  static const double _playlistItemFontSizeDelta = 4;
  static const double _playlistCheckboxScale = 0.85;

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
    final textTheme = Theme.of(context).textTheme;
    final isAnyUpdating = _updatingPlaylistIds.isNotEmpty;
    final isBottomDrawer =
        widget.presentation == MoviePlaylistPickerPresentation.bottomDrawer;
    final playlistList = ListView.separated(
      key: const Key('movie-playlist-list'),
      shrinkWrap: true,
      itemCount: _playlists.length,
      separatorBuilder: (context, index) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        final playlist = _playlists[index];
        final selected = _selectedPlaylistIds.contains(playlist.id);
        return InkWell(
          key: Key('movie-playlist-option-${playlist.id}'),
          borderRadius: context.appRadius.xsBorder,
          onTap: isAnyUpdating ? null : () => _togglePlaylist(playlist),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: spacing.md),
            decoration: BoxDecoration(
              color: context.appColors.surfaceMuted,
              borderRadius: context.appRadius.xsBorder,
              border: Border.all(
                color:
                    selected
                        ? Theme.of(context).colorScheme.primary
                        : context.appColors.borderSubtle,
              ),
            ),
            child: Row(
              children: [
                Transform.scale(
                  key: Key('movie-playlist-checkbox-scale-${playlist.id}'),
                  scale: _playlistCheckboxScale,
                  child: Checkbox(
                    key: Key('movie-playlist-checkbox-${playlist.id}'),
                    value: selected,
                    onChanged:
                        isAnyUpdating ? null : (_) => _togglePlaylist(playlist),
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Text(
                    playlist.name,
                    style: _reduceFontSize(textTheme.bodyLarge),
                  ),
                ),
                if (playlist.movieCount > 0)
                  Text(
                    '${playlist.movieCount}',
                    style: _reduceFontSize(textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        );
      },
    );

    final content = Stack(
      alignment: Alignment.center,
      children: [
        AbsorbPointer(
          absorbing: isAnyUpdating,
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
                isBottomDrawer
                    ? const Flexible(
                      fit: FlexFit.loose,
                      child: Center(
                        key: Key('movie-playlist-loading'),
                        child: CircularProgressIndicator(),
                      ),
                    )
                    : const SizedBox(
                      key: Key('movie-playlist-loading'),
                      height: 160,
                      child: Center(child: CircularProgressIndicator()),
                    )
              else if (_errorMessage != null)
                isBottomDrawer
                    ? Flexible(
                      fit: FlexFit.loose,
                      child: AppEmptyState(message: _errorMessage!),
                    )
                    : SizedBox(
                      height: 160,
                      child: AppEmptyState(message: _errorMessage!),
                    )
              else if (_playlists.isEmpty)
                isBottomDrawer
                    ? const Flexible(
                      fit: FlexFit.loose,
                      child: Center(child: Text('暂无播放列表')),
                    )
                    : const SizedBox(
                      height: 160,
                      child: Center(child: Text('暂无播放列表')),
                    )
              else if (isBottomDrawer)
                Flexible(fit: FlexFit.loose, child: playlistList)
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: playlistList,
                ),
            ],
          ),
        ),
        if (isAnyUpdating)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
      ],
    );

    if (!isBottomDrawer) {
      return AppDesktopDialog(
        dialogKey: const Key('movie-playlist-picker-dialog'),
        width: context.appComponentTokens.playlistDialogWidth,
        child: content,
      );
    }

    return content;
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
    final playlist = await showCreatePlaylistDialog(
      context,
      presentation:
          widget.presentation == MoviePlaylistPickerPresentation.bottomDrawer
              ? CreatePlaylistDialogPresentation.bottomDrawer
              : CreatePlaylistDialogPresentation.dialog,
    );
    if (!mounted || playlist == null) {
      return;
    }
    setState(() {
      _playlists = <PlaylistDto>[playlist, ..._playlists];
    });
    await _togglePlaylist(playlist);
  }

  TextStyle? _reduceFontSize(TextStyle? style) {
    final fontSize = style?.fontSize;
    if (style == null || fontSize == null) {
      return style;
    }
    final reduced = fontSize - _playlistItemFontSizeDelta;
    return style.copyWith(fontSize: reduced > 0 ? reduced : fontSize);
  }
}
