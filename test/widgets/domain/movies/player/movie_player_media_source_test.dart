import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/media/playback_source.dart';
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
        providerKey: cloud115PlaybackProviderKey,
      );

      expect(media.httpHeaders, <String, String>{
        'User-Agent': cloud115PlaybackUserAgent,
      });
      expect(
        playbackProviderKeyFromExtras(media.extras),
        cloud115PlaybackProviderKey,
      );
    });

    test('all platforms use the Flutter subtitle renderer', () {
      expect(buildMoviePlayerConfiguration().libass, isFalse);
    });
  });
}
