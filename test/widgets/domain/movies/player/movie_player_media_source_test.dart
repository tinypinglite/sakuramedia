import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_media_source.dart';

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
