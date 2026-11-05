import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranked_movie_list_item_dto.dart';

void main() {
  test(
    'resolution parses valid media and survives subscription updates and rankings',
    () {
      for (final entry in <String?, int>{
        null: 0,
        '': 0,
        '1920x1080': 1920,
        '3840x2160': 3840,
        '7680x4320': 7680,
        '8192x4096': 8192,
        '7680x3840': 7680,
        '4096x1716': 4096,
        '4096x2048': 4096,
        '3840x1920': 3840,
        '3840x1600': 3840,
        '7680x0': 0,
        'bad': 0,
        '0x4320': 0,
      }.entries) {
        final json = <String, dynamic>{
          'media_items': [
            {'resolution': entry.key},
            {'resolution': '15360x8640', 'valid': false},
          ],
        };
        final movie = MovieListItemDto.fromJson(json);
        expect(movie.maxMediaWidth, entry.value);
        expect(
          movie.copyWithSubscriptionStatus(true).maxMediaWidth,
          entry.value,
        );
        expect(
          RankedMovieListItemDto.fromJson(
            json,
          ).copyWithSubscriptionStatus(true).toMovieListItem().maxMediaWidth,
          entry.value,
        );
      }
      expect(MovieListItemDto.fromJson({}).maxMediaWidth, 0);
      expect(
        MovieListItemDto.fromJson({
          'media_items': [
            {'resolution': '7680x4320'},
            {'resolution': '3840x2160'},
          ],
        }).maxMediaWidth,
        7680,
      );
    },
  );
}
