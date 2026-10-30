import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranked_movie_list_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_card.dart';
import 'package:sakuramedia/theme.dart';

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
  testWidgets(
    'quality icons respect thresholds and status visibility; taps still work',
    (tester) async {
      var taps = 0;
      var subscriptions = 0;
      for (final width in [0, 1920, 3839, 3840, 7679, 7680]) {
        for (final hidden in [false, true]) {
          for (final selection in [false, true]) {
            await tester.pumpWidget(
              MaterialApp(
                locale: const Locale('zh'),
                localizationsDelegates: <LocalizationsDelegate<dynamic>>[
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
                theme: sakuraThemeData,
                home: Scaffold(
                  body: SizedBox(
                    width: 120,
                    child: MovieSummaryCard(
                      movie: MovieListItemDto.fromJson({
                        'movie_number': 'TEST',
                        'can_play': true,
                        'heat': 4321,
                        'media_items': [
                          {'resolution': '${width}x1920'},
                        ],
                      }),
                      showStatusBadges: !hidden,
                      selectionMode: selection,
                      onTap: () => taps++,
                      onSubscriptionTap: () => subscriptions++,
                    ),
                  ),
                ),
              ),
            );
            expect(
              find.text('8K'),
              width >= 7680 && !hidden && !selection
                  ? findsOneWidget
                  : findsNothing,
            );
            expect(
              find.text('4K'),
              width >= 3840 && width < 7680 && !hidden && !selection
                  ? findsOneWidget
                  : findsNothing,
            );
            if (width >= 3840 && !hidden && !selection) {
              final quality = tester.getRect(
                find.byKey(const Key('movie-summary-card-resolution-TEST')),
              );
              final heat = tester.getRect(
                find.byKey(const Key('movie-summary-card-heat-TEST')),
              );
              final subscription = tester.getRect(
                find.byKey(const Key('movie-summary-card-subscription-TEST')),
              );
              // 左上角一行：订阅心、清晰度胶囊依次排列。
              expect(quality.left, greaterThan(subscription.right));
              expect(quality.top, subscription.top);
              // 卡片只有 120 宽，热度折到下一行，不压住角标。
              expect(quality.overlaps(heat), isFalse);
              expect(subscription.overlaps(heat), isFalse);
              expect(heat.left, subscription.left);
              expect(heat.top, greaterThan(quality.bottom));
              // 固定宽度的烟熏角标不能把 4K/8K 文本挤成省略号。
              expect(
                tester
                    .renderObject<RenderParagraph>(
                      find.text(width >= 7680 ? '8K' : '4K'),
                    )
                    .didExceedMaxLines,
                isFalse,
              );
            }
            // 清晰度蕴含可播放：4K/8K 卡不再重复显示可播放标。
            expect(
              find.byKey(const Key('movie-summary-card-status-playable-TEST')),
              width < 3840 && !hidden && !selection
                  ? findsOneWidget
                  : findsNothing,
            );
            expect(tester.takeException(), isNull);
            if (!hidden && !selection) {
              await tester.tap(
                find.byKey(const Key('movie-summary-card-TEST')),
              );
              await tester.tapAt(
                tester.getCenter(
                  find.byKey(const Key('movie-summary-card-subscription-TEST')),
                ),
              );
            }
          }
        }
      }
      expect(taps, 6);
      expect(subscriptions, 6);
    },
  );
}
