import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/create_playlist_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_header.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';

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
      return showAppDialog<void>(
        context: context,
        builder: (dialogContext) => MoviePlaylistPickerDialog(
          movieNumber: movieNumber,
          initialPlaylists: initialPlaylists,
          presentation: MoviePlaylistPickerPresentation.dialog,
        ),
      );
    case MoviePlaylistPickerPresentation.bottomDrawer:
      return showAppBottomDrawer<void>(
        context: context,
        drawerKey: const Key('movie-playlist-picker-bottom-sheet'),
        heightFactor: 0.7,
        builder: (sheetContext) => MoviePlaylistPickerDialog(
          movieNumber: movieNumber,
          initialPlaylists: initialPlaylists,
          presentation: MoviePlaylistPickerPresentation.bottomDrawer,
        ),
      );
  }
}

class MoviePlaylistPickerDialog extends ConsumerStatefulWidget {
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
  ConsumerState<MoviePlaylistPickerDialog> createState() =>
      _MoviePlaylistPickerDialogState();
}

class _MoviePlaylistPickerDialogState
    extends ConsumerState<MoviePlaylistPickerDialog> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<PlaylistDto> _playlists = const <PlaylistDto>[];
  late Set<int> _selectedPlaylistIds;
  final Set<int> _updatingPlaylistIds = <int>{};
  String _keyword = '';
  bool _isLoading = true;
  String? _errorMessage;

  List<PlaylistDto> get _visiblePlaylists {
    if (_keyword.isEmpty) {
      return _playlists;
    }
    return _playlists
        .where((playlist) => playlist.name.toLowerCase().contains(_keyword))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _selectedPlaylistIds = widget.initialPlaylists
        .map((playlist) => playlist.id)
        .toSet();
    _load();
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final playlists = await ref.read(playlistsApiProvider).getPlaylists();
      if (!mounted) {
        return;
      }
      setState(() {
        _playlists = playlists
            .where(
              (playlist) =>
                  !playlist.isSystem || playlist.kind == PlaylistKind.favorites,
            )
            .toList(growable: false);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = AppLocalizations.of(context).playlistPickerLoadFailed;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    final l10n = AppLocalizations.of(context);
    final isBottomDrawer =
        widget.presentation == MoviePlaylistPickerPresentation.bottomDrawer;
    final visiblePlaylists = _visiblePlaylists;
    final Widget body;
    if (_isLoading) {
      body = const AppPickerIosState(
        key: Key('movie-playlist-loading'),
        loading: true,
      );
    } else if (_errorMessage != null) {
      body = AppPickerIosStateWithAction(
        state: AppPickerIosState(
          message: _errorMessage!,
          onRetry: () => _load(showLoading: true),
          retryKey: const Key('movie-playlist-retry'),
        ),
        action: _buildCreateRow(l10n),
      );
    } else if (_playlists.isEmpty) {
      body = AppPickerIosStateWithAction(
        state: AppPickerIosState(message: l10n.playlistEmpty),
        action: _buildCreateRow(l10n),
      );
    } else if (visiblePlaylists.isEmpty) {
      body = AppPickerIosStateWithAction(
        state: AppPickerIosState(message: l10n.playlistNoMatch),
        action: _buildCreateRow(l10n),
      );
    } else {
      body = SingleChildScrollView(
        controller: _scrollController,
        key: const Key('movie-playlist-list'),
        child: AppPickerIosSection(
          header: Text(
            l10n.commonSelectedCount(_selectedPlaylistIds.length),
            key: const Key('movie-playlist-selected-count'),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
          children: [
            _buildCreateRow(l10n),
            for (final playlist in visiblePlaylists)
              AppPickerIosRow(
                selected: _selectedPlaylistIds.contains(playlist.id),
                showCheckmark: true,
                enabled: !_updatingPlaylistIds.contains(playlist.id),
                busy: _updatingPlaylistIds.contains(playlist.id),
                busyKey: Key('movie-playlist-updating-${playlist.id}'),
                onTap: () => _togglePlaylist(playlist),
                title: playlist.name,
                trailingText: l10n.playlistMovieCountShort(playlist.movieCount),
                optionKey: Key('movie-playlist-option-${playlist.id}'),
              ),
          ],
        ),
      );
    }
    final content = Column(
      mainAxisSize: isBottomDrawer ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPickerHeader(
          title: l10n.playlistAddToPlaylist,
          searchController: _searchController,
          searchFieldKey: const Key('movie-playlist-search-field'),
          searchHintText: l10n.playlistSearchHint,
          onSearchChanged: (value) =>
              setState(() => _keyword = value.trim().toLowerCase()),
          clearSearchKey: const Key('movie-playlist-search-clear'),
          onClose: () => Navigator.of(context).pop(),
          closeKey: const Key('movie-playlist-close-button'),
          doneKey: const Key('movie-playlist-done-button'),
        ),
        SizedBox(height: spacing.lg),
        AppPickerListFrame(isDrawer: isBottomDrawer, child: body),
      ],
    );
    if (!isBottomDrawer) {
      return AppDesktopDialog(
        dialogKey: const Key('movie-playlist-picker-dialog'),
        width: tokens.playlistDialogWidth,
        showCloseButton: false,
        child: content,
      );
    }
    return content;
  }

  Widget _buildCreateRow(AppLocalizations l10n) {
    return AppPickerIosActionRow(
      label: l10n.playlistCreateTitle,
      onTap: _createPlaylist,
      optionKey: const Key('movie-playlist-create-button'),
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
        await ref
            .read(playlistsApiProvider)
            .removeMovieFromPlaylist(
              playlistId: playlist.id,
              movieNumber: widget.movieNumber,
            );
      } else {
        await ref
            .read(playlistsApiProvider)
            .addMovieToPlaylist(
              playlistId: playlist.id,
              movieNumber: widget.movieNumber,
            );
      }
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        if (isSelected) {
          _selectedPlaylistIds.add(playlist.id);
        } else {
          _selectedPlaylistIds.remove(playlist.id);
        }
      });
      showToast(
        apiErrorMessage(
          error,
          fallback: isSelected
              ? l10n.playlistRemoveFailed
              : l10n.playlistAddFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
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
}
