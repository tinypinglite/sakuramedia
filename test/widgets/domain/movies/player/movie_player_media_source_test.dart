import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_media_source.dart';

void main() {
  group('Movie player configuration', () {
    test('native media uses the stable generic browser user agent', () {
      final media = buildMoviePlayerMedia(
        'https://example.com/media/1/stream',
        startPosition: const Duration(seconds: 12),
        isWeb: false,
      );

      expect(media.start, const Duration(seconds: 12));
      expect(media.httpHeaders, <String, String>{
        'User-Agent': moviePlayerUserAgent,
      });
      expect(moviePlayerUserAgent, isNot(contains('SakuraMedia')));
    });

    test('web media leaves user agent ownership to the browser', () {
      final media = buildMoviePlayerMedia(
        'https://example.com/media/2/stream',
        isWeb: true,
      );

      expect(media.httpHeaders, isNull);
    });

    test('desktop configuration enables libass subtitles', () {
      expect(
        buildMoviePlayerConfiguration(
          isWeb: false,
          platform: TargetPlatform.macOS,
        ).libass,
        isTrue,
      );
      expect(
        buildMoviePlayerConfiguration(
          isWeb: false,
          platform: TargetPlatform.windows,
        ).libass,
        isTrue,
      );
    });

    test('mobile and web configuration keep libass disabled', () {
      expect(
        buildMoviePlayerConfiguration(
          isWeb: false,
          platform: TargetPlatform.android,
        ).libass,
        isFalse,
      );
      expect(
        buildMoviePlayerConfiguration(
          isWeb: false,
          platform: TargetPlatform.iOS,
        ).libass,
        isFalse,
      );
      expect(
        buildMoviePlayerConfiguration(
          isWeb: true,
          platform: TargetPlatform.macOS,
        ).libass,
        isFalse,
      );
    });
  });
}
