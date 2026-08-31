import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_media_source.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_playback_error_overlay.dart';

void main() {
  testWidgets('shows generic provider playback error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: MoviePlayerPlaybackErrorOverlay(
            sourceKind: MoviePlayerMediaSourceKind.unknown,
          ),
        ),
      ),
    );

    expect(find.text('播放失败'), findsOneWidget);
    expect(find.text('暂时无法播放此媒体。'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });
}
