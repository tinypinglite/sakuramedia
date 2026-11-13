import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/media/playback_user_agent.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_player_content.dart';

void main() {
  group('Movie player configuration', () {
    test('native media uses the stable generic browser user agent', () {
      final media = buildMoviePlayerMedia(
        'https://example.com/media/1/play/?expires=1777777777&signature=abc',
        startPosition: const Duration(seconds: 12),
      );

      expect(media.start, const Duration(seconds: 12));
      expect(media.httpHeaders, <String, String>{
        'User-Agent': moviePlayerUserAgent,
      });
      expect(moviePlayerUserAgent, isNot(contains('SakuraMedia')));
    });

    test('cloud115 media uses the official iOS app user agent', () {
      final media = buildMoviePlayerMedia(
        'https://example.com/media/1/play/?expires=1777777777&signature=abc',
        userAgent: cloud115PlaybackUserAgent,
      );

      expect(media.httpHeaders, <String, String>{
        'User-Agent': cloud115PlaybackUserAgent,
      });
    });

    test('desktop configuration enables libass subtitles', () {
      expect(
        buildMoviePlayerConfiguration(platform: TargetPlatform.macOS).libass,
        isTrue,
      );
      expect(
        buildMoviePlayerConfiguration(platform: TargetPlatform.windows).libass,
        isTrue,
      );
    });

    test('mobile configuration keeps libass disabled', () {
      expect(
        buildMoviePlayerConfiguration(platform: TargetPlatform.android).libass,
        isFalse,
      );
      expect(
        buildMoviePlayerConfiguration(platform: TargetPlatform.iOS).libass,
        isFalse,
      );
    });
  });
}
