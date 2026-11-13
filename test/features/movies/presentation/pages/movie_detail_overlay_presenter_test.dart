import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_menu.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_overlay_presenter.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_inspector_panel.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/preview_helpers.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;
  final movie = _movie();
  final media = movie.mediaItems.first;
  const candidates = <MovieMergePlaybackCandidateDto>[
    MovieMergePlaybackCandidateDto(
      libraryId: 1,
      libraryName: 'Library A',
      providerKey: 'library-a',
      segmentCount: 2,
    ),
    MovieMergePlaybackCandidateDto(
      libraryId: 2,
      libraryName: 'Library B',
      providerKey: 'library-b',
      segmentCount: 3,
    ),
  ];

  setUp(() async {
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('mobile presenter uses drawers and returns user choices', (
    tester,
  ) async {
    await _pumpHost(
      tester,
      bundle,
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      appPlatform: AppPlatform.mobile,
    );
    final context = tester.element(find.byType(Scaffold));
    const presenter = MovieDetailOverlayPresenter(mobile: true);

    final actionFuture = presenter.showActionMenu(
      context: context,
      globalPosition: Offset.zero,
      movie: movie,
      isSubscribed: true,
      isCollection: false,
      isBlacklisted: false,
      selectedMedia: media,
      castSessionLabel: null,
      canCast: false,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('movie-detail-hero-action-toggleSubscription')),
    );
    await tester.pumpAndSettle();
    expect(await actionFuture, MovieDetailActionType.toggleSubscription);

    final refreshCancel = presenter.confirmRefreshMetadata(
      context: context,
      isActorsManuallyManaged: false,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('movie-detail-refresh-metadata-cancel')),
    );
    await tester.pumpAndSettle();
    expect(await refreshCancel, isFalse);

    final deleteFuture = presenter.confirmDeleteMedia(
      context: context,
      mediaItem: media,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('movie-media-delete-confirm-drawer')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('movie-media-delete-cancel')));
    await tester.pumpAndSettle();
    expect(await deleteFuture, isFalse);

    final mergeFuture = presenter.pickMergeCandidate(
      context: context,
      candidates: candidates,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('movie-merge-playback-library-drawer')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('movie-merge-playback-library-2')));
    await tester.pumpAndSettle();
    expect(await mergeFuture, candidates[1]);

    final inspectorFuture = presenter.openInspector(
      context: context,
      movie: movie,
      selectedMedia: media,
      pane: MovieDetailInspectorPane.magnetSearch,
      onSearchSimilar: (_, _, _) async {},
      onPlay: (_) {},
    );
    await tester.pumpAndSettle();
    final inspector = find.byKey(
      const Key('movie-detail-inspector-bottom-sheet'),
    );
    expect(inspector, findsOneWidget);
    Navigator.of(tester.element(inspector)).pop();
    await tester.pumpAndSettle();
    await inspectorFuture;
  });

  testWidgets('desktop presenter uses dialogs and returns user choices', (
    tester,
  ) async {
    await _pumpHost(
      tester,
      bundle,
      size: const Size(1100, 760),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      appPlatform: AppPlatform.desktop,
    );
    final context = tester.element(find.byType(Scaffold));
    const presenter = MovieDetailOverlayPresenter(mobile: false);

    final actionFuture = presenter.showActionMenu(
      context: context,
      globalPosition: const Offset(300, 240),
      movie: movie,
      isSubscribed: true,
      isCollection: false,
      isBlacklisted: false,
      selectedMedia: media,
      castSessionLabel: null,
      canCast: false,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('movie-detail-hero-action-toggleSubscription')),
    );
    await tester.pumpAndSettle();
    expect(await actionFuture, MovieDetailActionType.toggleSubscription);

    final refreshConfirm = presenter.confirmRefreshMetadata(
      context: context,
      isActorsManuallyManaged: true,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('movie-detail-refresh-metadata-confirm')),
    );
    await tester.pumpAndSettle();
    expect(await refreshConfirm, isTrue);

    final deleteFuture = presenter.confirmDeleteMedia(
      context: context,
      mediaItem: media,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('movie-media-delete-confirm-dialog')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('movie-media-delete-cancel')));
    await tester.pumpAndSettle();
    expect(await deleteFuture, isFalse);

    final mergeFuture = presenter.pickMergeCandidate(
      context: context,
      candidates: candidates,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('movie-merge-playback-library-dialog')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('movie-merge-playback-library-1')));
    await tester.pumpAndSettle();
    expect(await mergeFuture, candidates.first);

    final inspectorFuture = presenter.openInspector(
      context: context,
      movie: movie,
      selectedMedia: media,
      pane: MovieDetailInspectorPane.magnetSearch,
      onSearchSimilar: (_, _, _) async {},
      onPlay: (_) {},
    );
    await tester.pumpAndSettle();
    final inspector = find.byKey(const Key('movie-detail-inspector-dialog'));
    expect(inspector, findsOneWidget);
    Navigator.of(tester.element(inspector)).pop();
    await tester.pumpAndSettle();
    await inspectorFuture;
  });

  testWidgets('desktop review inspector paints skeletons on the first frame', (
    tester,
  ) async {
    await _pumpHost(
      tester,
      bundle,
      size: const Size(1100, 760),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      appPlatform: AppPlatform.desktop,
    );
    final context = tester.element(find.byType(Scaffold));
    const presenter = MovieDetailOverlayPresenter(mobile: false);

    final inspectorFuture = presenter.openInspector(
      context: context,
      movie: movie,
      selectedMedia: media,
      pane: MovieDetailInspectorPane.review,
      onSearchSimilar: (_, _, _) async {},
      onPlay: (_) {},
    );
    await tester.pump();

    expect(
      find.byKey(const Key('movie-detail-inspector-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-detail-review-skeleton-0')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('movie-detail-review-list')), findsNothing);

    final inspector = find.byKey(const Key('movie-detail-inspector-dialog'));
    Navigator.of(tester.element(inspector)).pop();
    await tester.pumpAndSettle();
    await inspectorFuture;
  });

  testWidgets('mobile review inspector paints skeletons on the first frame', (
    tester,
  ) async {
    await _pumpHost(
      tester,
      bundle,
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      appPlatform: AppPlatform.mobile,
    );
    final context = tester.element(find.byType(Scaffold));
    const presenter = MovieDetailOverlayPresenter(mobile: true);

    final inspectorFuture = presenter.openInspector(
      context: context,
      movie: movie,
      selectedMedia: media,
      pane: MovieDetailInspectorPane.review,
      onSearchSimilar: (_, _, _) async {},
      onPlay: (_) {},
    );
    await tester.pump();

    expect(
      find.byKey(const Key('movie-detail-inspector-bottom-sheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-detail-review-skeleton-0')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('movie-detail-review-list')), findsNothing);

    final inspector = find.byKey(
      const Key('movie-detail-inspector-bottom-sheet'),
    );
    Navigator.of(tester.element(inspector)).pop();
    await tester.pumpAndSettle();
    await inspectorFuture;
  });
}

Future<void> _pumpHost(
  WidgetTester tester,
  TestApiBundle bundle, {
  required Size size,
  required ThemeData theme,
  required TargetPlatform platform,
  required AppPlatform appPlatform,
}) {
  return pumpPreviewApp(
    tester,
    home: const SizedBox.shrink(),
    size: size,
    theme: theme,
    platform: platform,
    appPlatform: appPlatform,
    bundle: bundle,
  );
}

MovieDetailDto _movie() {
  return MovieDetailDto.fromJson(<String, dynamic>{
    'id': 5,
    'movie_number': 'ABC-001',
    'title': 'Movie 1',
    'release_date': '2024-01-02',
    'duration_minutes': 120,
    'is_collection': false,
    'is_subscribed': true,
    'can_play': true,
    'summary': '',
    'actors': const <Map<String, dynamic>>[],
    'tags': const <Map<String, dynamic>>[],
    'plot_images': const <Map<String, dynamic>>[],
    'media_items': <Map<String, dynamic>>[
      <String, dynamic>{
        'media_id': 10,
        'file_name': 'movie-10.mp4',
        'file_size_bytes': 1024,
        'duration_seconds': 60,
        'play_url': 'https://cdn.example.com/movie-10.mp4',
        'valid': true,
        'points': const <Map<String, dynamic>>[],
      },
    ],
    'playlists': const <Map<String, dynamic>>[],
  });
}
