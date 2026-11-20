import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/tv/tv_playlist_card.dart';

class TvPlaylistRail extends StatelessWidget {
  const TvPlaylistRail({
    super.key,
    required this.playlists,
    required this.coverUrlFor,
    required this.onPressed,
  });

  final List<PlaylistDto> playlists;
  final String? Function(int playlistId) coverUrlFor;
  final void Function(PlaylistDto playlist) onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppTvTokens.playlistCardHeight + AppTvTokens.focusOverflow * 2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          vertical: AppTvTokens.focusOverflow,
        ),
        itemCount: playlists.length,
        separatorBuilder: (context, index) =>
            SizedBox(width: AppTvTokens.railGap),
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          return TvPlaylistCard(
            playlist: playlist,
            coverUrl: coverUrlFor(playlist.id),
            onPressed: () => onPressed(playlist),
          );
        },
      ),
    );
  }
}
