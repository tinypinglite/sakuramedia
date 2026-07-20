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
        find.text(
          '暂时无法播放此 115 网盘媒体。请检查网络或媒体库认证状态；如需重新认证，请前往「系统设置 → 媒体库」。',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('重试'), findsNothing);
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
