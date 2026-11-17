import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_player_content.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/pump_with_providers.dart';

void main() {
  testWidgets('播放失败浮层点击重试触发回调', (tester) async {
    var retryCount = 0;

    await pumpWithProviders(
      tester,
      theme: buildSakuraMobileThemeData(),
      physicalSize: const Size(390, 844),
      home: MoviePlayerPlaybackErrorOverlay(
        onRetry: () => retryCount += 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('movie-player-playback-error-retry')),
    );
    await tester.pump();

    expect(retryCount, 1);
  });
}
