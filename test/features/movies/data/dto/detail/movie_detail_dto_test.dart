import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

void main() {
  test('movie detail parses ranking placements', () {
    final zh = AppLocalizationsZh();
    final detail = MovieDetailDto.fromJson(<String, dynamic>{
      'rankings': <dynamic>[
        <String, dynamic>{
          'source_key': 'javdb',
          'source_name': 'JavDB',
          'board_key': 'playback_all',
          'board_name': '热播',
          'period': 'daily',
          'rank': 3,
        },
        <String, dynamic>{
          'source_key': 'javdb',
          'source_name': 'JavDB',
          'board_key': 'top250',
          'board_name': 'TOP250',
          'period': '2026',
          'rank': 28,
        },
      ],
    });

    expect(detail.rankings, hasLength(2));
    final daily = detail.rankings.first;
    expect(daily.sourceKey, 'javdb');
    expect(daily.sourceName, 'JavDB');
    expect(daily.boardKey, 'playback_all');
    expect(daily.boardName, '热播');
    expect(daily.period, 'daily');
    expect(daily.periodLabel(zh), zh.rankingPeriodDaily);
    expect(daily.rank, 3);
    expect(detail.rankings.last.periodLabel(zh), zh.rankingPeriodYear('2026'));
  });

  test('movie detail without rankings yields an empty list', () {
    final detail = MovieDetailDto.fromJson(<String, dynamic>{});

    expect(detail.rankings, isEmpty);
  });

  test('movie detail parses manual actor list ownership', () {
    final managed = MovieDetailDto.fromJson(<String, dynamic>{
      'is_actors_manually_managed': true,
    });
    final automatic = MovieDetailDto.fromJson(<String, dynamic>{});

    expect(managed.isActorsManuallyManaged, isTrue);
    expect(automatic.isActorsManuallyManaged, isFalse);
  });

  test('movie detail parses media file tags and manual lock', () {
    final detail = MovieDetailDto.fromJson(<String, dynamic>{
      'media_items': <dynamic>[
        <String, dynamic>{
          'media_id': 12,
          'play_url': '/media/12',
          'file_name': 'ABC-001.mkv',
          'tags': [
            {'id': 1, 'name': '4K'},
          ],
          'is_media_tags_manually_managed': true,
        },
      ],
    });

    final media = detail.mediaItems.single;
    expect(media.tags.single.name, '4K');
    expect(media.isMediaTagsManuallyManaged, isTrue);
  });
}
