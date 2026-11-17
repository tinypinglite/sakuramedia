import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_subscription_batch_dto.dart';

void main() {
  group('MovieSubscriptionSkipReason.fromWire', () {
    test('maps documented codes', () {
      expect(
        MovieSubscriptionSkipReason.fromWire('movie_not_found'),
        MovieSubscriptionSkipReason.movieNotFound,
      );
      expect(
        MovieSubscriptionSkipReason.fromWire('has_media'),
        MovieSubscriptionSkipReason.hasMedia,
      );
    });

    test('falls back to unknown for null / empty / unrecognized codes', () {
      expect(
        MovieSubscriptionSkipReason.fromWire(null),
        MovieSubscriptionSkipReason.unknown,
      );
      expect(
        MovieSubscriptionSkipReason.fromWire(''),
        MovieSubscriptionSkipReason.unknown,
      );
      expect(
        MovieSubscriptionSkipReason.fromWire('some_future_reason'),
        MovieSubscriptionSkipReason.unknown,
      );
    });
  });

  group('MovieSubscriptionBatchResultDto.fromJson', () {
    test('parses full payload with mixed skip reasons', () {
      final result = MovieSubscriptionBatchResultDto.fromJson(<String, dynamic>{
        'requested_count': 3,
        'updated_count': 1,
        'skipped_count': 2,
        'skipped': <Map<String, dynamic>>[
          <String, dynamic>{'movie_number': 'ABP-124', 'reason': 'has_media'},
          <String, dynamic>{
            'movie_number': 'NOT-EXIST-999',
            'reason': 'movie_not_found',
          },
        ],
      });

      expect(result.requestedCount, 3);
      expect(result.updatedCount, 1);
      expect(result.skippedCount, 2);
      expect(result.skipped, hasLength(2));
      expect(
        result.movieNumbersSkippedBecause(MovieSubscriptionSkipReason.hasMedia),
        <String>['ABP-124'],
      );
      expect(
        result.movieNumbersSkippedBecause(
          MovieSubscriptionSkipReason.movieNotFound,
        ),
        <String>['NOT-EXIST-999'],
      );
    });

    test(
      'unknown skip reason preserves raw string and falls back to unknown',
      () {
        final result = MovieSubscriptionBatchResultDto.fromJson(
          <String, dynamic>{
            'requested_count': 1,
            'updated_count': 0,
            'skipped_count': 1,
            'skipped': <Map<String, dynamic>>[
              <String, dynamic>{
                'movie_number': 'ABC-001',
                'reason': 'brand_new_reason',
              },
            ],
          },
        );

        expect(
          result.skipped.single.reason,
          MovieSubscriptionSkipReason.unknown,
        );
        expect(result.skipped.single.rawReason, 'brand_new_reason');
      },
    );

    test(
      'missing counts / skipped list falls back to zeros and empty list',
      () {
        final result = MovieSubscriptionBatchResultDto.fromJson(
          <String, dynamic>{},
        );

        expect(result.requestedCount, 0);
        expect(result.updatedCount, 0);
        expect(result.skippedCount, 0);
        expect(result.skipped, isEmpty);
      },
    );

    test('non-list skipped field is treated as empty', () {
      final result = MovieSubscriptionBatchResultDto.fromJson(<String, dynamic>{
        'requested_count': 1,
        'updated_count': 1,
        'skipped_count': 0,
        'skipped': 'not-a-list',
      });

      expect(result.skipped, isEmpty);
    });

    test(
      'non-map skip entries are dropped, movie_number defaults to empty',
      () {
        final result = MovieSubscriptionBatchResultDto.fromJson(
          <String, dynamic>{
            'requested_count': 2,
            'updated_count': 0,
            'skipped_count': 2,
            'skipped': <dynamic>[
              'not-a-map',
              <String, dynamic>{'reason': 'has_media'},
            ],
          },
        );

        expect(result.skipped, hasLength(1));
        expect(result.skipped.single.movieNumber, '');
        expect(
          result.skipped.single.reason,
          MovieSubscriptionSkipReason.hasMedia,
        );
      },
    );
  });
}
