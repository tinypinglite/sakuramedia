import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sakuramedia/core/media/providers/player_subtitle_preference_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/video/player_subtitle_view_configuration.dart';

void main() {
  testWidgets(
    'subtitle uses shadow without a background and keeps a safe inset',
    (tester) async {
      late SubtitleViewConfiguration configuration;

      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(bottom: 12)),
            child: Builder(
              builder: (context) {
                configuration = buildPlayerSubtitleViewConfiguration(
                  context: context,
                  preference: const PlayerSubtitlePreference(
                    scale: 1.25,
                    bottomOffset: 36,
                  ),
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(configuration.style.backgroundColor, isNull);
      expect(configuration.style.shadows, isNotEmpty);
      expect(configuration.padding.left, 0);
      expect(configuration.padding.top, 0);
      expect(configuration.padding.right, 0);
      expect(configuration.padding.bottom, greaterThan(12 + 36));
    },
  );
}
