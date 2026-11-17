import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/movie_number_matcher.dart';

void main() {
  group('isExactMovieNumberMatch', () {
    test('matches case and separator variants', () {
      expect(
        isExactMovieNumberMatch(
          storedMovieNumber: 'ssni_888',
          query: 'SSNI-888',
        ),
        isTrue,
      );
      expect(
        isExactMovieNumberMatch(
          storedMovieNumber: 'SSNI888',
          query: 'SSNI-888',
        ),
        isTrue,
      );
      expect(
        isExactMovieNumberMatch(
          storedMovieNumber: 'SSNI-888',
          query: 'ssni888',
        ),
        isTrue,
      );
    });

    test('does not match a different series or a prefix', () {
      expect(
        isExactMovieNumberMatch(
          storedMovieNumber: 'SNI-888',
          query: 'SSNI-888',
        ),
        isFalse,
      );
      expect(
        isExactMovieNumberMatch(
          storedMovieNumber: 'ABC-1234',
          query: 'ABC-123',
        ),
        isFalse,
      );
    });

    test('folds FC2 PPV variants', () {
      expect(
        isExactMovieNumberMatch(
          storedMovieNumber: 'FC2-PPV-123',
          query: 'FC2-123',
        ),
        isTrue,
      );
      expect(
        isExactMovieNumberMatch(
          storedMovieNumber: 'fc2ppv_123',
          query: 'FC2-123',
        ),
        isTrue,
      );
      expect(
        isExactMovieNumberMatch(storedMovieNumber: 'FC2-124', query: 'FC2-123'),
        isFalse,
      );
    });

    test('keeps separator differences for pure-digit numbers', () {
      expect(
        isExactMovieNumberMatch(
          storedMovieNumber: '123456_789',
          query: '123456-789',
        ),
        isFalse,
      );
      expect(
        isExactMovieNumberMatch(
          storedMovieNumber: '123456789',
          query: '123456-789',
        ),
        isFalse,
      );
      expect(
        isExactMovieNumberMatch(
          storedMovieNumber: '123456-789',
          query: '123456789',
        ),
        isTrue,
      );
      expect(
        isExactMovieNumberMatch(
          storedMovieNumber: '123456_789',
          query: '123456789',
        ),
        isTrue,
      );
    });
  });
}
