import 'package:flutter/material.dart';
import 'package:sakuramedia/widgets/base/media/video/themed_video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:oktoast/oktoast.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_collection_play_content.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collection_playback_factory_provider.dart';
import 'package:sakuramedia/widgets/domain/media/movie_media_thumbnail_grid.dart';
import 'package:sakuramedia/widgets/domain/movies/player/merged_position_indicator.dart';
import 'package:sakuramedia/theme.dart';
import '../../../../support/test_api_bundle.dart';
import '../../../../support/test_playlist_player.dart';

class _Controller extends Fake implements VideoController {
  _Controller(this.player);
  @override
  final Player player;
  @override
  final notifier = ValueNotifier<PlatformVideoController?>(null);
  @override
  Future<void> get waitUntilFirstFrameRendered => Future.value();
}

void main() {
  for (final mobile in [false, true]) {
    testWidgets('${mobile ? '移动' : '桌面'}真实播放页在窗口和全屏同步选集、缩略图与进度', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = mobile
          ? const Size(844, 390)
          : const Size(1100, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.alexmercerind/media_kit_video'),
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('com.alexmercerind/media_kit_video'),
          null,
        ),
      );
      final session = SessionStore.inMemory();
      await session.saveBaseUrl('https://api.example.com');
      await session.saveTokens(
        accessToken: 'test',
        refreshToken: 'test',
        expiresAt: DateTime(2030),
      );
      final bundle = await createTestApiBundle(session);
      addTearDown(bundle.dispose);
      addTearDown(session.dispose);
      final items = [
        for (var i = 0; i < 3; i++)
          VideoCollectionItemDto.fromJson({
            'item_id': 100 + i,
            'position': i,
            'first_media_id': i + 1,
            'play_url': 'https://api.example.com/media/${i + 1}/play/',
            'video': {
              'id': i + 1,
              'title': '选集 ${i + 1}',
              'duration_seconds': [600, 1200, 1800][i],
              'media_count': 1,
              'can_play': true,
            },
          }),
      ];
      bundle.collectionPlaybackHandoff.offerVideoItems(
        collectionId: 3,
        sort: null,
        items: items,
      );
      for (var i = 1; i <= 3; i++) {
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/media/$i/thumbnails',
          body: [
            {
              'thumbnail_id': i,
              'media_id': i,
              'offset_seconds': 0,
              'image': {},
            },
          ],
        );
      }
      final native = TestPlaylistPlayer();
      final player = Player(platformPlayer: native);
      final controller = _Controller(player);
      addTearDown(controller.notifier.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...bundle.riverpodOverrides(),
            videoCollectionPlaybackFactoryProvider.overrideWithValue(
              () => (player: player, videoController: controller),
            ),
          ],
          child: OKToast(
            child: MaterialApp(
              theme: mobile ? sakuraMobileThemeData : sakuraThemeData,
              home: VideoCollectionPlayContent(
                collectionId: 3,
                startIndex: 2,
                useTouchOptimizedControls: mobile,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      native.select(2, const Duration(minutes: 5), playing: false);
      await tester.pump();
      Future<void> openEpisodes() async {
        final controls = tester
            .widget<ThemedVideoPlayer>(
              find.byType(ThemedVideoPlayer, skipOffstage: false),
            )
            .bottomControls;
        if (mobile) {
          controls.whereType<MaterialCustomButton>().single.onPressed();
        } else {
          controls.whereType<MaterialDesktopCustomButton>().single.onPressed();
        }
      }

      final split = tester.widget<MultiSplitView>(find.byType(MultiSplitView));
      split.controller!.areas[0].flex = 0.65;
      split.controller!.areas[1].flex = 0.35;
      await tester.pumpAndSettle();
      void expectEpisodesInsidePlayer() {
        final playerBounds = tester.getRect(
          find.byKey(const Key('video-collection-play-left-panel')),
        );
        final episodes = tester.getRect(
          find.byKey(const Key('episode-selector-list')),
        );
        expect(episodes.right, closeTo(playerBounds.right, 0.01));
        expect(episodes.left, greaterThanOrEqualTo(playerBounds.left));
        expect(episodes.bottom, lessThanOrEqualTo(playerBounds.bottom));
      }

      await openEpisodes();
      await tester.pumpAndSettle();
      expect(find.text('选集 · 3'), findsOneWidget);
      expectEpisodesInsidePlayer();
      final originalSize = tester.view.physicalSize;
      tester.view.physicalSize = mobile
          ? const Size(760, 360)
          : const Size(800, 600);
      await tester.pumpAndSettle();
      expectEpisodesInsidePlayer();
      tester.view.physicalSize = originalSize;
      await tester.pumpAndSettle();
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/video-collections/3/items/100',
        statusCode: 204,
      );
      await tester.tap(find.byKey(const Key('video-episode-more-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('video-episode-action-remove')));
      await tester.pumpAndSettle();
      expect(find.text('选集 · 2'), findsOneWidget);
      expect(native.state.playlist.index, 1);
      expect(native.state.position, const Duration(minutes: 5));
      expect(native.calls.where((call) => call == 'open'), hasLength(1));
      final grid = tester.widget<MovieMediaThumbnailGrid>(
        find.byType(MovieMediaThumbnailGrid),
      );
      expect(grid.thumbnails.map((frame) => frame.mediaId), [2, 3]);
      expect(grid.onThumbnailMenuRequested, isNotNull);
      Navigator.of(tester.element(find.text('选集 · 2'))).pop();
      await tester.pumpAndSettle();
      await tester
          .state<VideoState>(find.byType(Video).first)
          .enterFullscreen();
      await tester.pumpAndSettle();
      await openEpisodes();
      await tester.pumpAndSettle();
      expect(find.text('选集 · 2'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const Key('episode-selector-list'))).right,
        tester.view.physicalSize.width,
      );
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/videos/2',
        statusCode: 204,
      );
      await tester.tap(find.byKey(const Key('video-episode-more-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('video-episode-action-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('video-episode-delete-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('选集 · 1'), findsOneWidget);
      expect(native.state.playlist.index, 0);
      expect(native.state.position, const Duration(minutes: 5));
      final indicators = tester.widgetList<MergedPositionIndicator>(
        find.byType(MergedPositionIndicator, skipOffstage: false),
      );
      expect(
        indicators,
        everyElement(
          isA<MergedPositionIndicator>().having(
            (w) => w.episodeDurationsSeconds,
            'durations',
            [1800],
          ),
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/videos/3',
        statusCode: 204,
      );
      await tester.tap(find.byKey(const Key('video-episode-more-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('video-episode-action-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('video-episode-delete-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('合集内暂无可播放视频'), findsOneWidget);
      expect(find.byType(Video), findsOneWidget);
      expect(native.state.playlist.medias, isEmpty);
      expect(
        bundle.adapter.requests.where(
          (r) => r.method == 'GET' && r.path.endsWith('/thumbnails'),
        ),
        hasLength(3),
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
