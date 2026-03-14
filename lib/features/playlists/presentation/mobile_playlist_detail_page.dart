import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/features/playlists/presentation/playlist_detail_content.dart';
import 'package:sakuramedia/theme.dart';

class MobilePlaylistDetailPage extends StatelessWidget {
  const MobilePlaylistDetailPage({super.key, required this.playlistId});

  final int playlistId;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('mobile-playlist-detail-page'),
      color: context.appColors.surfacePage,
      child: PlaylistDetailContent(
        playlistId: playlistId,
        onMovieTap: (_) => showToast('移动端影片详情开发中'),
      ),
    );
  }
}
