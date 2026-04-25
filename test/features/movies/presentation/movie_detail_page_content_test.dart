import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_page_content.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_bottom_info_bar.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_stat_row.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_tag_wrap.dart';

void main() {
  testWidgets('movie detail page content exposes clickable series row', (
    WidgetTester tester,
  ) async {
    var tapCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraMobileThemeData,
        home: Scaffold(
          body: MovieDetailPageContent(
            movie: _movieDetail(seriesId: 7),
            selectedPreviewKey: 'movie-preview',
            selectedPreviewUrl: null,
            isCollection: false,
            isSubscribed: false,
            isCollectionUpdating: false,
            isSubscriptionUpdating: false,
            selectedMediaId: 100,
            statItems: const <MovieDetailStatItem>[],
            similarMovies: const <MovieListItemDto>[],
            isSimilarMoviesLoading: false,
            onInspectorTap: _noop,
            onPlaylistTap: _noop,
            onCollectionToggle: _noop,
            onMediaSelect: (_) {},
            onSeriesTap: () => tapCount += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('movie-detail-series-link')));
    await tester.pump();

    expect(tapCount, 1);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
  });

  testWidgets('movie detail page content keeps series text plain without id', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraMobileThemeData,
        home: Scaffold(
          body: MovieDetailPageContent(
            movie: _movieDetail(),
            selectedPreviewKey: 'movie-preview',
            selectedPreviewUrl: null,
            isCollection: false,
            isSubscribed: false,
            isCollectionUpdating: false,
            isSubscriptionUpdating: false,
            selectedMediaId: 100,
            statItems: const <MovieDetailStatItem>[],
            similarMovies: const <MovieListItemDto>[],
            isSimilarMoviesLoading: false,
            onInspectorTap: _noop,
            onPlaylistTap: _noop,
            onCollectionToggle: _noop,
            onMediaSelect: (_) {},
            onSeriesTap: _noop,
          ),
        ),
      ),
    );

    expect(find.text('系列 · Attackers'), findsOneWidget);
    expect(find.byKey(const Key('movie-detail-series-link')), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });

  testWidgets(
    'movie detail page content keeps grouped meta spacing in mobile theme',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraMobileThemeData,
          home: Scaffold(
            body: MovieDetailPageContent(
              movie: _movieDetail(),
              selectedPreviewKey: 'movie-preview',
              selectedPreviewUrl: null,
              isCollection: false,
              isSubscribed: false,
              isCollectionUpdating: false,
              isSubscriptionUpdating: false,
              selectedMediaId: 100,
              statItems: const <MovieDetailStatItem>[
                MovieDetailStatItem(
                  icon: Icons.calendar_today_outlined,
                  label: '26/03/08',
                  tooltip: '发行日期',
                  iconColor: Color(0xFF6B625E),
                ),
              ],
              similarMovies: const <MovieListItemDto>[],
              isSimilarMoviesLoading: false,
              bottomInfoBarVariant:
                  MovieDetailBottomInfoBarVariant.mobileFullWidth,
              onInspectorTap: _noop,
              onPlaylistTap: _noop,
              onCollectionToggle: _noop,
              onMediaSelect: (_) {},
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.text('演员'));
      await tester.pumpAndSettle();

      final sectionGap = AppComponentTokens.mobile().movieDetailSectionGap;
      final seriesBottom = tester.getBottomLeft(find.text('系列 · Attackers')).dy;
      final makerTop = tester.getTopLeft(find.text('厂商 · S1 NO.1 STYLE')).dy;
      final makerBottom =
          tester.getBottomLeft(find.text('厂商 · S1 NO.1 STYLE')).dy;
      final directorTop = tester.getTopLeft(find.text('导演 · 紋℃')).dy;
      final metaGroupBottom =
          tester
              .getBottomLeft(
                find.byKey(const Key('movie-detail-inline-meta-group')),
              )
              .dy;
      final tagTop = tester.getTopLeft(find.text('标签')).dy;
      final tagWrapBottom = tester.getBottomLeft(find.byType(MovieTagWrap)).dy;
      final actorTop = tester.getTopLeft(find.text('演员')).dy;

      expect(makerTop - seriesBottom, sakuraMobileThemeData.appSpacing.sm);
      expect(directorTop - makerBottom, sakuraMobileThemeData.appSpacing.sm);
      expect(makerTop - seriesBottom, lessThan(sectionGap));
      expect(directorTop - makerBottom, lessThan(sectionGap));
      expect(tagTop - metaGroupBottom, sectionGap);
      expect(actorTop - tagWrapBottom, sectionGap);
      expect(find.text('媒体源'), findsOneWidget);
    },
  );
}

MovieDetailDto _movieDetail({int? seriesId}) {
  return MovieDetailDto(
    javdbId: 'javdb-1',
    movieNumber: 'ABC-001',
    title: 'Sample Movie',
    titleZh: '',
    seriesId: seriesId,
    seriesName: 'Attackers',
    makerName: 'S1 NO.1 STYLE',
    directorName: '紋℃',
    coverImage: null,
    releaseDate: null,
    durationMinutes: 120,
    score: 4.5,
    heat: 12,
    watchedCount: 12,
    wantWatchCount: 23,
    commentCount: 45,
    scoreNumber: 45,
    isCollection: false,
    isSubscribed: false,
    canPlay: false,
    summary: '',
    descZh: '中文简介',
    desc: '',
    thinCoverImage: null,
    plotImages: const <MovieImageDto>[],
    actors: const <MovieActorDto>[
      MovieActorDto(
        id: 1,
        javdbId: 'actor-1',
        name: '演员一',
        aliasName: '演员一',
        gender: MovieActorDto.femaleGender,
        isSubscribed: false,
        profileImage: null,
      ),
      MovieActorDto(
        id: 2,
        javdbId: 'actor-2',
        name: '演员二',
        aliasName: '演员二',
        gender: 0,
        isSubscribed: false,
        profileImage: null,
      ),
    ],
    tags: const <MovieTagDto>[
      MovieTagDto(tagId: 1, name: '单体作品'),
      MovieTagDto(tagId: 2, name: '剧情'),
    ],
    mediaItems: const <MovieMediaItemDto>[
      MovieMediaItemDto(
        mediaId: 100,
        libraryId: 1,
        playUrl: '',
        path: '/library/ABC-001/video.mp4',
        storageMode: 'hardlink',
        resolution: '1920x1080',
        fileSizeBytes: 1073741824,
        durationSeconds: 7200,
        specialTags: '普通',
        valid: true,
        progress: null,
        points: <MovieMediaPointDto>[],
      ),
    ],
    playlists: const <MoviePlaylistSummaryDto>[],
  );
}

void _noop() {}
