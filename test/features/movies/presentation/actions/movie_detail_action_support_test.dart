import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_menu.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_support.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/l10n/app_localizations_en.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

/// 中日韩统一表意文字，用于判定「英文界面漏出中文」。
final RegExp _cjk = RegExp(r'[\u4e00-\u9fff]');

String _labelOf(
  List<MovieDetailActionDescriptor> actions,
  MovieDetailActionType type,
) {
  return actions.firstWhere((action) => action.type == type).label;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'buildMovieDetailActionDescriptors keeps action order and prerequisites',
    () {
      final actions = buildMovieDetailActionDescriptors(
        l10n: AppLocalizationsZh(),
        isSubscribed: false,
        isCollection: false,
        isBlacklisted: false,
      );

      expect(actions.map((action) => action.type), <MovieDetailActionType>[
        MovieDetailActionType.toggleSubscription,
        MovieDetailActionType.openMagnetSearch,
        MovieDetailActionType.toggleCollectionType,
        MovieDetailActionType.toggleBlacklist,
      ]);
      expect(
        actions
            .firstWhere(
              (action) =>
                  action.type == MovieDetailActionType.toggleCollectionType,
            )
            .label,
        isNotEmpty,
      );

      final blacklistedActions = buildMovieDetailActionDescriptors(
        l10n: AppLocalizationsZh(),
        isSubscribed: false,
        isCollection: true,
        isBlacklisted: true,
      );
      expect(
        blacklistedActions.map((action) => action.type),
        isNot(contains(MovieDetailActionType.toggleSubscription)),
      );
      // 合集 / 单体、屏蔽 / 取消屏蔽是两种不同意图，文案必须能区分。
      expect(
        _labelOf(
          blacklistedActions,
          MovieDetailActionType.toggleCollectionType,
        ),
        isNot(_labelOf(actions, MovieDetailActionType.toggleCollectionType)),
      );
      expect(
        _labelOf(blacklistedActions, MovieDetailActionType.toggleBlacklist),
        isNot(_labelOf(actions, MovieDetailActionType.toggleBlacklist)),
      );
    },
  );

  test('buildMovieDetailActionDescriptors follows the caller locale', () {
    final en = buildMovieDetailActionDescriptors(
      l10n: AppLocalizationsEn(),
      isSubscribed: false,
      isCollection: false,
      isBlacklisted: false,
      canCast: true,
    );
    final zh = buildMovieDetailActionDescriptors(
      l10n: AppLocalizationsZh(),
      isSubscribed: false,
      isCollection: false,
      isBlacklisted: false,
      canCast: true,
    );

    // 英文界面不得出现中文：操作菜单曾经整段硬编码中文。
    for (final action in en) {
      expect(_cjk.hasMatch(action.label), isFalse);
    }
    expect(
      en.map((action) => action.label),
      isNot(zh.map((action) => action.label)),
    );
  });

  test(
    'buildMovieDetailActionDescriptors prepends cast action when enabled',
    () {
      final actions = buildMovieDetailActionDescriptors(
        l10n: AppLocalizationsZh(),
        isSubscribed: false,
        isCollection: false,
        isBlacklisted: false,
        canCast: true,
      );

      expect(actions.first.type, MovieDetailActionType.castToDevice);
      expect(actions.first.label, isNotEmpty);
    },
  );

  test('buildMovieDetailActionDescriptors shows casting label when active', () {
    final actions = buildMovieDetailActionDescriptors(
      l10n: AppLocalizationsZh(),
      isSubscribed: false,
      isCollection: false,
      isBlacklisted: false,
      castSessionLabel: 'Living room TV',
    );

    expect(actions.first.type, MovieDetailActionType.castToDevice);
    // 正在投屏时优先显示调用方给的会话名，而不是通用「投屏到电视」。
    expect(actions.first.label, 'Living room TV');
  });

  testWidgets(
    'applyReturnedMovieDetail keeps selected media when still present',
    (WidgetTester tester) async {
      final result = await _runApplyReturnedMovieDetail(
        tester,
        movie: _movieDetail(mediaIds: const <int>[10, 20]),
        selectedMediaId: 20,
      );

      expect(result.selectedMediaId, 20);
      expect(result.isSubscribedOverride, isNull);
      expect(result.isCollectionOverride, isNull);
    },
  );

  testWidgets(
    'applyReturnedMovieDetail falls back to first media when selection disappears',
    (WidgetTester tester) async {
      final result = await _runApplyReturnedMovieDetail(
        tester,
        movie: _movieDetail(mediaIds: const <int>[30, 40]),
        selectedMediaId: 20,
      );

      expect(result.selectedMediaId, 30);
    },
  );

  testWidgets(
    'applyReturnedMovieDetail clears selection when no media remain',
    (WidgetTester tester) async {
      final result = await _runApplyReturnedMovieDetail(
        tester,
        movie: _movieDetail(mediaIds: const <int>[]),
        selectedMediaId: 20,
      );

      expect(result.selectedMediaId, isNull);
    },
  );

  testWidgets(
    'resolveMovieSubscriptionNotifier returns the same events notifier '
    'that publishers use',
    (WidgetTester tester) async {
      late MovieSubscriptionEvents resolved;
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context, listen: false);
                resolved = resolveMovieSubscriptionNotifier(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(
        resolved,
        same(container.read(movieSubscriptionEventsProvider.notifier)),
      );
    },
  );
}

/// applyReturnedMovieDetail 需要 [WidgetRef]，用最小 widget test 抓一个 ref。
/// 在 post-frame 里跑，避免 Consumer build 中修改 provider 触发的
/// 「build 中不得修改 provider」断言。
Future<MovieDetailApplyResult> _runApplyReturnedMovieDetail(
  WidgetTester tester, {
  required MovieDetailDto movie,
  required int? selectedMediaId,
  bool resetPreview = false,
  String movieNumber = 'ABC-001',
}) async {
  final completer = Completer<MovieDetailApplyResult>();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (completer.isCompleted) return;
              completer.complete(
                applyReturnedMovieDetail(
                  ref: ref,
                  movieNumber: movieNumber,
                  movie: movie,
                  selectedMediaId: selectedMediaId,
                  resetPreview: resetPreview,
                ),
              );
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pump();
  return completer.future;
}

MovieDetailDto _movieDetail({
  List<int> mediaIds = const <int>[10, 20],
  List<MoviePlaylistSummaryDto> playlists = const <MoviePlaylistSummaryDto>[],
  int? favoritePlaylistId,
}) {
  return MovieDetailDto(
    movieNumber: 'ABC-001',
    title: 'Movie',
    seriesName: '',
    makerName: '',
    directorName: '',
    coverImage: const MovieImageDto(id: 1, origin: '/covers/1.jpg'),
    releaseDate: DateTime.parse('2024-01-01'),
    durationMinutes: 120,
    interactionStats: const <String, num>{'score': 4.5},
    statsSource: 'legacy:host',
    heat: 12,
    isCollection: false,
    isSubscribed: false,
    canPlay: true,
    summary: '',
    thinCoverImage: null,
    plotImages: const <MovieImageDto>[],
    actors: const <MovieActorDto>[],
    tags: const <MovieTagDto>[],
    mediaItems: mediaIds
        .map(
          (mediaId) => MovieMediaItemDto(
            mediaId: mediaId,
            libraryId: 1,
            providerKey: 'filesystem',
            playUrl: '/play/$mediaId',
            fileName: 'movie.mp4',
            resolution: '1080p',
            fileSizeBytes: 10,
            durationSeconds: 120,
            valid: true,
            progress: null,
            points: const <MovieMediaPointDto>[],
            videoInfo: null,
          ),
        )
        .toList(growable: false),
    playlists: playlists,
    favoritePlaylistId: favoritePlaylistId,
  );
}
