import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_player_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, Object?>> progressReports;
  late List<int> thumbnailRequests;

  MovieDetailDto buildMovieDetail({List<MovieMediaItemDto>? mediaItems}) {
    return MovieDetailDto(
      javdbId: 'MovieA1',
      movieNumber: 'ABC-001',
      title: 'Movie 1',
      seriesName: '',
      coverImage: null,
      releaseDate: DateTime.parse('2026-03-08'),
      durationMinutes: 120,
      score: 4.5,
      watchedCount: 12,
      wantWatchCount: 23,
      commentCount: 34,
      scoreNumber: 45,
      isCollection: false,
      isSubscribed: true,
      canPlay: true,
      summary: '',
      thinCoverImage: null,
      plotImages: const <MovieImageDto>[],
      actors: const <MovieActorDto>[],
      tags: const <MovieTagDto>[],
      playlists: const <MoviePlaylistSummaryDto>[],
      mediaItems:
          mediaItems ??
          <MovieMediaItemDto>[
            MovieMediaItemDto(
              mediaId: 100,
              libraryId: 1,
              playUrl: '/files/media/movies/ABC-001/video.mp4',
              path: '/library/main/ABC-001/video.mp4',
              storageMode: 'hardlink',
              resolution: '1920x1080',
              fileSizeBytes: 1024,
              durationSeconds: 7200,
              specialTags: '普通',
              valid: true,
              progress: const MovieMediaProgressDto(
                lastPositionSeconds: 12,
                lastWatchedAt: null,
              ),
              points: const <MovieMediaPointDto>[],
            ),
          ],
    );
  }

  List<MovieMediaThumbnailDto> buildThumbnails() {
    return <MovieMediaThumbnailDto>[
      MovieMediaThumbnailDto(
        thumbnailId: 1,
        mediaId: 100,
        offsetSeconds: 10,
        image: const MovieImageDto(
          id: 10,
          origin: 'thumb-10.webp',
          small: 'thumb-10.webp',
          medium: 'thumb-10.webp',
          large: 'thumb-10.webp',
        ),
      ),
      MovieMediaThumbnailDto(
        thumbnailId: 2,
        mediaId: 100,
        offsetSeconds: 20,
        image: const MovieImageDto(
          id: 11,
          origin: 'thumb-20.webp',
          small: 'thumb-20.webp',
          medium: 'thumb-20.webp',
          large: 'thumb-20.webp',
        ),
      ),
      MovieMediaThumbnailDto(
        thumbnailId: 3,
        mediaId: 100,
        offsetSeconds: 35,
        image: const MovieImageDto(
          id: 12,
          origin: 'thumb-35.webp',
          small: 'thumb-35.webp',
          medium: 'thumb-35.webp',
          large: 'thumb-35.webp',
        ),
      ),
    ];
  }

  setUp(() {
    progressReports = <Map<String, Object?>>[];
    thumbnailRequests = <int>[];
  });

  test('load fetches thumbnails for selected media', () async {
    final controller = MoviePlayerController(
      movieNumber: 'ABC-001',
      baseUrl: 'https://api.example.com',
      fetchMovieDetail: ({required movieNumber}) async => buildMovieDetail(),
      fetchMediaThumbnails: ({required mediaId}) async {
        thumbnailRequests.add(mediaId);
        return buildThumbnails();
      },
      updateMediaProgress: ({
        required mediaId,
        required positionSeconds,
      }) async {
        progressReports.add(<String, Object?>{
          'mediaId': mediaId,
          'positionSeconds': positionSeconds,
        });
        return MovieMediaProgressDto(
          lastPositionSeconds: positionSeconds,
          lastWatchedAt: DateTime.parse('2026-03-12T10:20:00Z'),
        );
      },
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.selectedMedia?.mediaId, 100);
    expect(controller.thumbnails, hasLength(3));
    expect(thumbnailRequests, <int>[100]);
    expect(controller.currentPlaybackSeconds, 12);
    expect(controller.activeThumbnailIndex, 0);
  });

  test(
    'load falls back to first playable media when initial media is invalid',
    () async {
      final controller = MoviePlayerController(
        movieNumber: 'ABC-001',
        baseUrl: 'https://api.example.com',
        initialMediaId: 999,
        fetchMovieDetail:
            ({required movieNumber}) async => buildMovieDetail(
              mediaItems: <MovieMediaItemDto>[
                MovieMediaItemDto(
                  mediaId: 90,
                  libraryId: 1,
                  playUrl: '',
                  path: '/library/main/ABC-001/video-broken.mp4',
                  storageMode: 'hardlink',
                  resolution: '1920x1080',
                  fileSizeBytes: 100,
                  durationSeconds: 7200,
                  specialTags: '',
                  valid: true,
                  progress: null,
                  points: const <MovieMediaPointDto>[],
                ),
                MovieMediaItemDto(
                  mediaId: 100,
                  libraryId: 1,
                  playUrl: '/files/media/movies/ABC-001/video.mp4',
                  path: '/library/main/ABC-001/video.mp4',
                  storageMode: 'hardlink',
                  resolution: '1920x1080',
                  fileSizeBytes: 100,
                  durationSeconds: 7200,
                  specialTags: '',
                  valid: true,
                  progress: null,
                  points: const <MovieMediaPointDto>[],
                ),
              ],
            ),
        fetchMediaThumbnails: ({required mediaId}) async => buildThumbnails(),
        updateMediaProgress: ({
          required mediaId,
          required positionSeconds,
        }) async {
          return MovieMediaProgressDto(
            lastPositionSeconds: positionSeconds,
            lastWatchedAt: null,
          );
        },
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.selectedMedia?.mediaId, 100);
    },
  );

  test('thumbnail load failure does not block resolved playback url', () async {
    final controller = MoviePlayerController(
      movieNumber: 'ABC-001',
      baseUrl: 'https://api.example.com',
      fetchMovieDetail: ({required movieNumber}) async => buildMovieDetail(),
      fetchMediaThumbnails: ({required mediaId}) async {
        throw Exception('boom');
      },
      updateMediaProgress: ({
        required mediaId,
        required positionSeconds,
      }) async {
        return MovieMediaProgressDto(
          lastPositionSeconds: positionSeconds,
          lastWatchedAt: null,
        );
      },
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(
      controller.resolvedPlayUrl,
      'https://api.example.com/files/media/movies/ABC-001/video.mp4',
    );
    expect(controller.thumbnailErrorMessage, isNotNull);
    expect(controller.thumbnails, isEmpty);
  });

  test(
    'thumbnail columns use auto value until user overrides manually',
    () async {
      final controller = MoviePlayerController(
        movieNumber: 'ABC-001',
        baseUrl: 'https://api.example.com',
        fetchMovieDetail: ({required movieNumber}) async => buildMovieDetail(),
        fetchMediaThumbnails: ({required mediaId}) async => buildThumbnails(),
        updateMediaProgress: ({
          required mediaId,
          required positionSeconds,
        }) async {
          return MovieMediaProgressDto(
            lastPositionSeconds: positionSeconds,
            lastWatchedAt: null,
          );
        },
      );
      addTearDown(controller.dispose);

      expect(controller.thumbnailColumns, isNull);

      controller.applyAutoThumbnailColumns(4);
      expect(controller.thumbnailColumns, 4);

      controller.setThumbnailColumns(2);
      expect(controller.thumbnailColumns, 2);

      controller.applyAutoThumbnailColumns(5);
      expect(controller.thumbnailColumns, 2);
    },
  );

  test(
    'thumbnail scroll lock is enabled by default and can be toggled',
    () async {
      final controller = MoviePlayerController(
        movieNumber: 'ABC-001',
        baseUrl: 'https://api.example.com',
        fetchMovieDetail: ({required movieNumber}) async => buildMovieDetail(),
        fetchMediaThumbnails: ({required mediaId}) async => buildThumbnails(),
        updateMediaProgress: ({
          required mediaId,
          required positionSeconds,
        }) async {
          return MovieMediaProgressDto(
            lastPositionSeconds: positionSeconds,
            lastWatchedAt: null,
          );
        },
      );
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() {
        notifications += 1;
      });

      expect(controller.isThumbnailScrollLocked, isTrue);

      controller.toggleThumbnailScrollLock();
      expect(controller.isThumbnailScrollLocked, isFalse);

      controller.toggleThumbnailScrollLock();
      expect(controller.isThumbnailScrollLocked, isTrue);
      expect(notifications, 2);
    },
  );

  test('handlePlaybackPosition updates active thumbnail index', () async {
    final controller = MoviePlayerController(
      movieNumber: 'ABC-001',
      baseUrl: 'https://api.example.com',
      fetchMovieDetail: ({required movieNumber}) async => buildMovieDetail(),
      fetchMediaThumbnails: ({required mediaId}) async => buildThumbnails(),
      updateMediaProgress: ({
        required mediaId,
        required positionSeconds,
      }) async {
        return MovieMediaProgressDto(
          lastPositionSeconds: positionSeconds,
          lastWatchedAt: null,
        );
      },
    );
    addTearDown(controller.dispose);
    await controller.load();

    controller.handlePlaybackPosition(const Duration(seconds: 34));
    expect(controller.activeThumbnailIndex, 1);

    controller.handlePlaybackPosition(const Duration(seconds: 35));
    expect(controller.activeThumbnailIndex, 2);
  });

  test(
    'handlePlaybackPosition ignores duplicate seconds without notifying page listeners',
    () async {
      final controller = MoviePlayerController(
        movieNumber: 'ABC-001',
        baseUrl: 'https://api.example.com',
        fetchMovieDetail: ({required movieNumber}) async => buildMovieDetail(),
        fetchMediaThumbnails: ({required mediaId}) async => buildThumbnails(),
        updateMediaProgress: ({
          required mediaId,
          required positionSeconds,
        }) async {
          return MovieMediaProgressDto(
            lastPositionSeconds: positionSeconds,
            lastWatchedAt: null,
          );
        },
      );
      addTearDown(controller.dispose);
      await controller.load();

      var pageNotifications = 0;
      controller.addListener(() {
        pageNotifications += 1;
      });

      controller.handlePlaybackPosition(const Duration(seconds: 30));
      controller.handlePlaybackPosition(const Duration(seconds: 30));

      expect(controller.currentPlaybackSeconds, 30);
      expect(pageNotifications, 0);
    },
  );

  test(
    'handlePlaybackPosition keeps page listeners silent when active index does not change',
    () async {
      final controller = MoviePlayerController(
        movieNumber: 'ABC-001',
        baseUrl: 'https://api.example.com',
        fetchMovieDetail: ({required movieNumber}) async => buildMovieDetail(),
        fetchMediaThumbnails: ({required mediaId}) async => buildThumbnails(),
        updateMediaProgress: ({
          required mediaId,
          required positionSeconds,
        }) async {
          return MovieMediaProgressDto(
            lastPositionSeconds: positionSeconds,
            lastWatchedAt: null,
          );
        },
      );
      addTearDown(controller.dispose);
      await controller.load();

      var pageNotifications = 0;
      controller.addListener(() {
        pageNotifications += 1;
      });

      controller.handlePlaybackPosition(const Duration(seconds: 15));

      expect(controller.currentPlaybackSeconds, 15);
      expect(controller.activeThumbnailIndex, 0);
      expect(pageNotifications, 0);
    },
  );

  test('active thumbnail notifier emits only when index changes', () async {
    final controller = MoviePlayerController(
      movieNumber: 'ABC-001',
      baseUrl: 'https://api.example.com',
      fetchMovieDetail: ({required movieNumber}) async => buildMovieDetail(),
      fetchMediaThumbnails: ({required mediaId}) async => buildThumbnails(),
      updateMediaProgress: ({
        required mediaId,
        required positionSeconds,
      }) async {
        return MovieMediaProgressDto(
          lastPositionSeconds: positionSeconds,
          lastWatchedAt: null,
        );
      },
    );
    addTearDown(controller.dispose);
    await controller.load();

    final activeIndexChanges = <int?>[];
    controller.activeThumbnailIndexListenable.addListener(() {
      activeIndexChanges.add(controller.activeThumbnailIndexListenable.value);
    });

    controller.handlePlaybackPosition(const Duration(seconds: 19));
    controller.handlePlaybackPosition(const Duration(seconds: 20));
    controller.handlePlaybackPosition(const Duration(seconds: 24));
    controller.handlePlaybackPosition(const Duration(seconds: 35));

    expect(activeIndexChanges, <int?>[1, 2]);
  });

  test(
    'initial playback position remains the startup position after playback updates',
    () async {
      final controller = MoviePlayerController(
        movieNumber: 'ABC-001',
        baseUrl: 'https://api.example.com',
        fetchMovieDetail: ({required movieNumber}) async => buildMovieDetail(),
        fetchMediaThumbnails: ({required mediaId}) async => buildThumbnails(),
        updateMediaProgress: ({
          required mediaId,
          required positionSeconds,
        }) async {
          return MovieMediaProgressDto(
            lastPositionSeconds: positionSeconds,
            lastWatchedAt: null,
          );
        },
      );
      addTearDown(controller.dispose);
      await controller.load();

      expect(controller.initialPlaybackPosition, const Duration(seconds: 12));

      controller.handlePlaybackPosition(const Duration(seconds: 35));

      expect(controller.currentPlaybackSeconds, 35);
      expect(controller.initialPlaybackPosition, const Duration(seconds: 12));
    },
  );

  test(
    'playing state starts periodic progress reporting and pauses stop it',
    () async {
      final controller = MoviePlayerController(
        movieNumber: 'ABC-001',
        baseUrl: 'https://api.example.com',
        fetchMovieDetail: ({required movieNumber}) async => buildMovieDetail(),
        fetchMediaThumbnails: ({required mediaId}) async => buildThumbnails(),
        updateMediaProgress: ({
          required mediaId,
          required positionSeconds,
        }) async {
          progressReports.add(<String, Object?>{
            'mediaId': mediaId,
            'positionSeconds': positionSeconds,
          });
          return MovieMediaProgressDto(
            lastPositionSeconds: positionSeconds,
            lastWatchedAt: null,
          );
        },
        progressReportInterval: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.handlePlaybackPosition(const Duration(seconds: 21));
      controller.handlePlaybackPlayingChanged(true);
      await Future<void>.delayed(const Duration(milliseconds: 25));
      controller.handlePlaybackPlayingChanged(false);
      final countAfterPause = progressReports.length;
      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(progressReports, isNotEmpty);
      expect(countAfterPause, progressReports.length);
    },
  );

  test('periodic progress reporting deduplicates unchanged seconds', () async {
    final controller = MoviePlayerController(
      movieNumber: 'ABC-001',
      baseUrl: 'https://api.example.com',
      fetchMovieDetail: ({required movieNumber}) async => buildMovieDetail(),
      fetchMediaThumbnails: ({required mediaId}) async => buildThumbnails(),
      updateMediaProgress: ({
        required mediaId,
        required positionSeconds,
      }) async {
        progressReports.add(<String, Object?>{
          'mediaId': mediaId,
          'positionSeconds': positionSeconds,
        });
        return MovieMediaProgressDto(
          lastPositionSeconds: positionSeconds,
          lastWatchedAt: null,
        );
      },
      progressReportInterval: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);
    await controller.load();

    controller.handlePlaybackPosition(const Duration(seconds: 30));
    controller.handlePlaybackPlayingChanged(true);
    await Future<void>.delayed(const Duration(milliseconds: 25));
    controller.handlePlaybackPlayingChanged(false);

    expect(progressReports, hasLength(1));
    expect(progressReports.single['positionSeconds'], 30);
  });

  test('flushPlaybackProgress reports pending position once', () async {
    final controller = MoviePlayerController(
      movieNumber: 'ABC-001',
      baseUrl: 'https://api.example.com',
      fetchMovieDetail: ({required movieNumber}) async => buildMovieDetail(),
      fetchMediaThumbnails: ({required mediaId}) async => buildThumbnails(),
      updateMediaProgress: ({
        required mediaId,
        required positionSeconds,
      }) async {
        progressReports.add(<String, Object?>{
          'mediaId': mediaId,
          'positionSeconds': positionSeconds,
        });
        return MovieMediaProgressDto(
          lastPositionSeconds: positionSeconds,
          lastWatchedAt: null,
        );
      },
    );
    addTearDown(controller.dispose);
    await controller.load();

    controller.handlePlaybackPosition(const Duration(seconds: 42));
    await controller.flushPlaybackProgress();
    await controller.flushPlaybackProgress();

    expect(progressReports, hasLength(1));
    expect(progressReports.single['positionSeconds'], 42);
  });
}
