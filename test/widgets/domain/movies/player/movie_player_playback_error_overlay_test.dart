import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_media_source.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_playback_error_overlay.dart';

void main() {
  group('MoviePlayerPlaybackErrorOverlay', () {
    testWidgets('shows cloud115 guidance without retry action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(
            body: MoviePlayerPlaybackErrorOverlay(
              sourceKind: MoviePlayerMediaSourceKind.cloud115,
            ),
          ),
        ),
      );

      expect(find.text('播放失败'), findsOneWidget);
      expect(
        find.text('该媒体来自 115 网盘，暂时无法播放。可稍后重试；如反复失败，可到「系统设置 → 媒体库」检查认证。'),
        findsOneWidget,
      );
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('shows local media wording', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(
            body: MoviePlayerPlaybackErrorOverlay(
              sourceKind: MoviePlayerMediaSourceKind.local,
            ),
          ),
        ),
      );

      expect(find.text('暂时无法播放此媒体。请检查媒体文件是否仍然可用。'), findsOneWidget);
    });
  });
}
