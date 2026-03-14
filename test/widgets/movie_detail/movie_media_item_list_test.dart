import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_pill_wrap.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_media_item_list.dart';

void main() {
  testWidgets(
    'movie media item list shows empty state when there are no media items',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: MovieMediaItemList(
              mediaItems: const <MovieMediaItemDto>[],
              selectedMediaId: null,
              onSelect: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('暂无媒体源'), findsOneWidget);
    },
  );

  testWidgets(
    'movie media item list renders compact shared pills and updates selected style',
    (WidgetTester tester) async {
      MovieMediaItemDto? selectedItem;

      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: MovieMediaItemList(
              mediaItems: const <MovieMediaItemDto>[
                MovieMediaItemDto(
                  mediaId: 100,
                  libraryId: 1,
                  playUrl: '/files/media/movies/ABC-001/video.mp4',
                  path: '/library/main/ABC-001/video.mp4',
                  storageMode: 'hardlink',
                  resolution: '1920x1080',
                  fileSizeBytes: 1073741824,
                  durationSeconds: 7200,
                  specialTags: '普通',
                  valid: false,
                  progress: MovieMediaProgressDto(
                    lastPositionSeconds: 600,
                    lastWatchedAt: null,
                  ),
                  points: <MovieMediaPointDto>[],
                ),
                MovieMediaItemDto(
                  mediaId: 101,
                  libraryId: 1,
                  playUrl: '/files/media/movies/ABC-001/video-alt.mp4',
                  path: '/library/main/ABC-001/video-alt.mp4',
                  storageMode: 'hardlink',
                  resolution: '1280x720',
                  fileSizeBytes: 524288000,
                  durationSeconds: 5400,
                  specialTags: '导演剪辑版',
                  valid: true,
                  progress: null,
                  points: <MovieMediaPointDto>[],
                ),
              ],
              selectedMediaId: 100,
              onSelect: (item) {
                selectedItem = item;
              },
            ),
          ),
        ),
      );

      expect(find.text('普通 1.0 GB'), findsOneWidget);
      expect(find.text('导演剪辑版 500.0 MB'), findsOneWidget);
      expect(find.byType(MovieDetailPillWrap), findsOneWidget);

      final selectedText = tester.widget<Text>(find.text('普通 1.0 GB'));
      final unselectedText = tester.widget<Text>(find.text('导演剪辑版 500.0 MB'));

      expect(selectedText.style?.fontWeight, FontWeight.w600);
      expect(unselectedText.style?.fontWeight, FontWeight.w500);

      await tester.tap(find.text('导演剪辑版 500.0 MB'));
      await tester.pump();

      expect(selectedItem?.mediaId, 101);
    },
  );
}
