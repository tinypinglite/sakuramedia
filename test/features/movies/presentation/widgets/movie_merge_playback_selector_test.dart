import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_merge_playback_candidates.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_merge_playback_models.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_merge_playback_selector.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

void main() {
  const movie = MovieDetailDto(
    movieNumber: 'TEST-001',
    title: '多版本影片',
    seriesName: '',
    makerName: '',
    directorName: '',
    coverImage: null,
    releaseDate: null,
    durationMinutes: 120,
    heat: 0,
    isCollection: false,
    isSubscribed: false,
    canPlay: true,
    summary: '',
    thinCoverImage: null,
    plotImages: <MovieImageDto>[],
    actors: <MovieActorDto>[],
    tags: <MovieTagDto>[],
    mediaItems: <MovieMediaItemDto>[
      MovieMediaItemDto(
        mediaId: 11,
        libraryId: 1,
        libraryName: '主媒体库',
        providerKey: 'local',
        playUrl: '/media/11/play/a.mp4',
        resolution: '2160x3840',
        fileName: 'TEST-001-4K-CD1.mp4',
        fileSizeBytes: 1000,
        durationSeconds: 600,
        valid: true,
        progress: null,
        points: <MovieMediaPointDto>[],
      ),
      MovieMediaItemDto(
        mediaId: 12,
        libraryId: 1,
        libraryName: '主媒体库',
        providerKey: 'local',
        playUrl: '/media/12/play/b.mp4',
        resolution: '1080x1920',
        fileName: 'TEST-001-1080P-CD1.mp4',
        fileSizeBytes: 800,
        durationSeconds: 600,
        valid: true,
        progress: null,
        points: <MovieMediaPointDto>[],
      ),
      MovieMediaItemDto(
        mediaId: 21,
        libraryId: 2,
        libraryName: '备用库',
        providerKey: 'local',
        playUrl: '/media/21/play/c.mp4',
        resolution: '1080x1920',
        fileName: 'TEST-001-1080P-CD2.mp4',
        fileSizeBytes: 700,
        durationSeconds: 600,
        valid: true,
        progress: null,
        points: <MovieMediaPointDto>[],
      ),
      MovieMediaItemDto(
        mediaId: 22,
        libraryId: 2,
        libraryName: '备用库',
        providerKey: 'local',
        playUrl: '/media/22/play/d.mp4',
        resolution: '1080x1920',
        fileName: 'TEST-001-1080P-CD3.mp4',
        fileSizeBytes: 700,
        durationSeconds: 600,
        valid: true,
        progress: null,
        points: <MovieMediaPointDto>[],
      ),
      MovieMediaItemDto(
        mediaId: 31,
        libraryId: 3,
        libraryName: '单文件库',
        providerKey: 'local',
        playUrl: '/media/31/play/e.mp4',
        resolution: '1080x1920',
        fileName: 'TEST-001-only.mp4',
        fileSizeBytes: 600,
        durationSeconds: 600,
        valid: true,
        progress: null,
        points: <MovieMediaPointDto>[],
      ),
    ],
    playlists: <MoviePlaylistSummaryDto>[],
  );

  Widget buildSelector({
    required Future<MovieMergePlaybackSubmission> Function(
      MovieMergePlaybackSelection selection,
    )
    onSubmit,
    bool? isDrawer,
    double height = 800,
  }) {
    final selector = SizedBox(
      width: 640,
      height: height,
      child: MovieMergePlaybackSelector(
        movie: movie,
        modeDescription: '将在应用内连续播放',
        onSubmit: onSubmit,
      ),
    );
    return MaterialApp(
      theme: buildSakuraDesktopThemeData(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: isDrawer == null
            ? selector
            : AppAdaptiveModalShellScope(isDrawer: isDrawer, child: selector),
      ),
    );
  }

  test('只把同库至少两个可播放文件算作合并候选', () {
    expect(movieMergePlaybackLibraryIds(movie), <int>[1, 2]);
    expect(
      movieMergePlaybackLibraryIds(movie, supportedLibraryIds: const <int>{2}),
      <int>[2],
    );
  });

  testWidgets('drawer shell shows the selector scroll cue', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(720, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      buildSelector(
        height: 320,
        isDrawer: true,
        onSubmit: (selection) async =>
            MovieMergePlaybackSubmission.inApp(selection: selection),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('app-bottom-drawer-scroll-cue')),
      findsOneWidget,
    );
  });

  testWidgets('unscoped selector keeps the drawer scroll cue', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(720, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      buildSelector(
        height: 320,
        onSubmit: (selection) async =>
            MovieMergePlaybackSubmission.inApp(selection: selection),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('app-bottom-drawer-scroll-cue')),
      findsOneWidget,
    );
  });

  testWidgets('dialog shell does not show the selector scroll cue', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(720, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      buildSelector(
        height: 320,
        isDrawer: false,
        onSubmit: (selection) async =>
            MovieMergePlaybackSubmission.inApp(selection: selection),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('movie-merge-playback-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(find.byKey(const Key('app-bottom-drawer-scroll-cue')), findsNothing);
  });

  testWidgets('按点击顺序编号并阻止跨媒体库选择', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(720, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      buildSelector(
        onSubmit: (selection) async =>
            MovieMergePlaybackSubmission.inApp(selection: selection),
      ),
    );

    expect(find.text('主媒体库'), findsOneWidget);
    expect(find.text('备用库'), findsOneWidget);

    await tester.tap(find.byKey(const Key('movie-merge-playback-file-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-merge-playback-file-12')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('movie-merge-playback-order-11')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('movie-merge-playback-order-12')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('movie-merge-playback-file-21')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('movie-merge-playback-order-21')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('movie-merge-playback-file-11')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('movie-merge-playback-order-11')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('movie-merge-playback-order-12')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('movie-merge-playback-clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-merge-playback-file-31')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('movie-merge-playback-order-31')),
      findsNothing,
    );
  });

  testWidgets('提交选中媒体 ID 的顺序', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(720, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    List<int>? submitted;

    await tester.pumpWidget(
      buildSelector(
        onSubmit: (selection) async {
          submitted = selection.mediaIds;
          return MovieMergePlaybackSubmission.inApp(selection: selection);
        },
      ),
    );

    await tester.tap(find.byKey(const Key('movie-merge-playback-file-12')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-merge-playback-file-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-merge-playback-submit')));
    await tester.pumpAndSettle();

    expect(submitted, <int>[12, 11]);
  });

  testWidgets('提交失败时保留选择并显示内联错误', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(720, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      buildSelector(
        onSubmit: (_) async =>
            throw const MovieMergePlaybackSubmitException('分段规格不一致，无法合并'),
      ),
    );

    await tester.tap(find.byKey(const Key('movie-merge-playback-file-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-merge-playback-file-12')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-merge-playback-submit')));
    await tester.pumpAndSettle();

    expect(find.text('分段规格不一致，无法合并'), findsOneWidget);
    expect(
      find.byKey(const Key('movie-merge-playback-order-11')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-merge-playback-order-12')),
      findsOneWidget,
    );
  });
}
