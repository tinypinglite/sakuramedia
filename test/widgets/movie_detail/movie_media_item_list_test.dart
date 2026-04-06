import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_pill_wrap.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_media_item_list.dart';

void main() {
  testWidgets(
    'movie media item list shows empty state when there are no media items',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _testApp(
          child: MovieMediaItemList(
            mediaItems: const <MovieMediaItemDto>[],
            selectedMediaId: null,
            onSelect: (_) {},
          ),
        ),
      );

      expect(find.text('暂无媒体源'), findsOneWidget);
    },
  );

  testWidgets(
    'movie media item list renders compact shared pills and updates selected style',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _testApp(
          child: _MovieMediaItemListHarness(
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
                points: <MovieMediaPointDto>[
                  MovieMediaPointDto(
                    pointId: 1,
                    thumbnailId: 11,
                    offsetSeconds: 120,
                    image: MovieImageDto(
                      id: 201,
                      origin: 'point-1-origin.webp',
                      small: 'point-1-small.webp',
                      medium: 'point-1-medium.webp',
                      large: 'point-1-large.webp',
                    ),
                  ),
                ],
                videoInfo: MovieMediaVideoInfoDto(
                  container: MovieMediaContainerInfoDto(
                    formatName: 'mpegts',
                    durationSeconds: 7200,
                    bitRate: 22793091,
                    sizeBytes: 1073741824,
                  ),
                  video: MovieMediaVideoStreamInfoDto(
                    codecName: 'h264',
                    codecLongName: '',
                    profile: 'High',
                    bitRate: null,
                    width: 1920,
                    height: 1080,
                    frameRate: 29.97,
                    pixelFormat: 'yuv420p',
                  ),
                  audio: null,
                  subtitles: <MovieMediaSubtitleInfoDto>[],
                ),
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
                points: <MovieMediaPointDto>[
                  MovieMediaPointDto(
                    pointId: 2,
                    thumbnailId: 22,
                    offsetSeconds: 240,
                    image: MovieImageDto(
                      id: 202,
                      origin: 'point-2-origin.webp',
                      small: 'point-2-small.webp',
                      medium: 'point-2-medium.webp',
                      large: 'point-2-large.webp',
                    ),
                  ),
                ],
                videoInfo: MovieMediaVideoInfoDto(
                  container: MovieMediaContainerInfoDto(
                    formatName: 'mp4',
                    durationSeconds: 5400,
                    bitRate: 8000000,
                    sizeBytes: 524288000,
                  ),
                  video: MovieMediaVideoStreamInfoDto(
                    codecName: 'hevc',
                    codecLongName: '',
                    profile: null,
                    bitRate: 6500000,
                    width: 1280,
                    height: 720,
                    frameRate: 24,
                    pixelFormat: 'yuv420p',
                  ),
                  audio: null,
                  subtitles: <MovieMediaSubtitleInfoDto>[],
                ),
              ),
            ],
          ),
        ),
      );

      expect(find.text('普通 1.0 GB'), findsOneWidget);
      expect(find.text('导演剪辑版 500.0 MB'), findsOneWidget);
      expect(find.byType(MovieDetailPillWrap), findsOneWidget);
      expect(find.byKey(const Key('movie-media-tech-summary')), findsOneWidget);
      expect(find.text('H.264 · 22.8 Mbps · 29.97 fps'), findsOneWidget);
      expect(
        find.byKey(const Key('movie-media-point-timecode-0')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('movie-media-point-timecode-0')))
            .data,
        '02:00',
      );

      final selectedText = tester.widget<Text>(find.text('普通 1.0 GB'));
      final unselectedText = tester.widget<Text>(find.text('导演剪辑版 500.0 MB'));

      expect(selectedText.style?.fontWeight, FontWeight.w600);
      expect(unselectedText.style?.fontWeight, FontWeight.w500);

      await tester.tap(find.text('导演剪辑版 500.0 MB'));
      await tester.pumpAndSettle();

      expect(find.text('H.265 · 6.5 Mbps · 24 fps'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('movie-media-point-timecode-0')))
            .data,
        '04:00',
      );
    },
  );

  testWidgets(
    'movie media item list hides technical summary when all summary fields are missing',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _testApp(
          child: MovieMediaItemList(
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
                valid: true,
                progress: null,
                points: <MovieMediaPointDto>[],
                videoInfo: MovieMediaVideoInfoDto(
                  container: MovieMediaContainerInfoDto(
                    formatName: '',
                    durationSeconds: null,
                    bitRate: null,
                    sizeBytes: null,
                  ),
                  video: MovieMediaVideoStreamInfoDto(
                    codecName: '',
                    codecLongName: '',
                    profile: null,
                    bitRate: null,
                    width: null,
                    height: null,
                    frameRate: null,
                    pixelFormat: '',
                  ),
                  audio: null,
                  subtitles: <MovieMediaSubtitleInfoDto>[],
                ),
              ),
            ],
            selectedMediaId: 100,
            onSelect: (_) {},
          ),
        ),
      );

      expect(find.byKey(const Key('movie-media-tech-summary')), findsNothing);
    },
  );
}

class _MovieMediaItemListHarness extends StatefulWidget {
  const _MovieMediaItemListHarness({required this.mediaItems});

  final List<MovieMediaItemDto> mediaItems;

  @override
  State<_MovieMediaItemListHarness> createState() =>
      _MovieMediaItemListHarnessState();
}

class _MovieMediaItemListHarnessState
    extends State<_MovieMediaItemListHarness> {
  int? _selectedMediaId = 100;

  @override
  Widget build(BuildContext context) {
    return MovieMediaItemList(
      mediaItems: widget.mediaItems,
      selectedMediaId: _selectedMediaId,
      onSelect: (item) {
        setState(() {
          _selectedMediaId = item.mediaId;
        });
      },
    );
  }
}

Widget _testApp({required Widget child}) {
  final sessionStore = SessionStore.inMemory();
  return ChangeNotifierProvider<SessionStore>.value(
    value: sessionStore,
    child: MaterialApp(theme: sakuraThemeData, home: Scaffold(body: child)),
  );
}
