import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_summary_card.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/app_cover_bottom_shade.dart';

void main() {
  late SessionStore sessionStore;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
  });

  tearDown(() => sessionStore.dispose());

  VideoItemListItemDto buildVideo({
    String title = '测试视频标题',
    bool canPlay = true,
    int durationSeconds = 754,
    int fileSizeBytes = 512 * 1024 * 1024,
  }) {
    return VideoItemListItemDto(
      id: 1,
      title: title,
      durationSeconds: durationSeconds,
      fileSizeBytes: fileSizeBytes,
      mediaCount: 1,
      canPlay: canPlay,
    );
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required VoidCallback onTap,
    VoidCallback? onPlay,
    VoidCallback? onThumbnails,
    VoidCallback? onAddToCollection,
    VoidCallback? onDelete,
    VideoItemListItemDto? video,
    bool selectionMode = false,
    ValueChanged<bool>? onSelectedChanged,
    double width = 560,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: VideoSummaryCard(
                    video: video ?? buildVideo(),
                    onTap: onTap,
                    onPlay: onPlay,
                    onThumbnails: onThumbnails,
                    onAddToCollection: onAddToCollection,
                    onDelete: onDelete,
                    selectionMode: selectionMode,
                    onSelectedChanged: onSelectedChanged,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> hoverCard(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(VideoSummaryCard)));
    await tester.pumpAndSettle();
  }

  testWidgets('video card keeps the cover clean until hovered', (
    WidgetTester tester,
  ) async {
    var tapped = 0;
    await pumpCard(tester, onTap: () => tapped++, onPlay: () {});

    // 收起态只有封面：无标题、无居中播放 icon、无悬停播放键、无底部压暗。
    expect(find.text('测试视频标题'), findsNothing);
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsNothing);
    expect(find.byKey(const Key('video-summary-card-play-1')), findsNothing);
    expect(find.byType(AppCoverBottomShade), findsNothing);

    await hoverCard(tester);

    // 悬停展开：标题、时长 · 大小与播放键。
    expect(find.text('测试视频标题'), findsOneWidget);
    expect(find.text('12:34 · 512.0 MB'), findsOneWidget);
    expect(find.byKey(const Key('video-summary-card-play-1')), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsNothing);
    expect(tapped, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('video card hover play button plays without opening the card', (
    WidgetTester tester,
  ) async {
    var tapped = 0;
    var played = 0;
    await pumpCard(
      tester,
      onTap: () => tapped++,
      onPlay: () => played++,
    );

    await hoverCard(tester);
    await tester.tap(find.byKey(const Key('video-summary-card-play-1')));
    await tester.pumpAndSettle();

    expect(played, 1);
    expect(tapped, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('video card tap outside the hover button opens the card', (
    WidgetTester tester,
  ) async {
    var tapped = 0;
    await pumpCard(tester, onTap: () => tapped++, onPlay: () {});

    await hoverCard(tester);
    await tester.tap(find.byKey(const Key('video-summary-card-tap-1')));
    await tester.pumpAndSettle();

    expect(tapped, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('video card hides the play button when playback is unavailable', (
    WidgetTester tester,
  ) async {
    await pumpCard(
      tester,
      onTap: () {},
      onPlay: () {},
      video: buildVideo(canPlay: false),
    );

    await hoverCard(tester);

    expect(find.text('测试视频标题'), findsOneWidget);
    expect(find.byKey(const Key('video-summary-card-play-1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('video card omits the meta line when duration and size are zero', (
    WidgetTester tester,
  ) async {
    await pumpCard(
      tester,
      onTap: () {},
      video: buildVideo(durationSeconds: 0, fileSizeBytes: 0),
    );

    await hoverCard(tester);

    expect(find.text('测试视频标题'), findsOneWidget);
    expect(find.textContaining(' · '), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('video card does not expand while selecting', (
    WidgetTester tester,
  ) async {
    var selected = 0;
    await pumpCard(
      tester,
      onTap: () {},
      onPlay: () {},
      selectionMode: true,
      onSelectedChanged: (_) => selected++,
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(VideoSummaryCard)));
    await tester.pumpAndSettle();

    expect(find.text('测试视频标题'), findsNothing);
    expect(find.byKey(const Key('video-summary-card-play-1')), findsNothing);

    await tester.tap(
      find.byKey(const Key('video-summary-card-select-1')),
    );
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('video card truncates a long title without overflowing', (
    WidgetTester tester,
  ) async {
    await pumpCard(
      tester,
      onTap: () {},
      onPlay: () {},
      video: buildVideo(
        title: '一个非常非常长的视频标题' * 8,
      ),
      width: 280,
    );

    await hoverCard(tester);

    expect(find.byKey(const Key('video-summary-card-play-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('video card hover action row triggers each callback', (
    WidgetTester tester,
  ) async {
    var thumbnails = 0;
    var addToCollection = 0;
    var delete = 0;
    await pumpCard(
      tester,
      onTap: () {},
      onThumbnails: () => thumbnails++,
      onAddToCollection: () => addToCollection++,
      onDelete: () => delete++,
    );

    await hoverCard(tester);

    await tester.tap(
      find.byKey(const Key('video-summary-card-thumbnails-1')),
    );
    await tester.tap(
      find.byKey(const Key('video-summary-card-add-collection-1')),
    );
    await tester.tap(find.byKey(const Key('video-summary-card-delete-1')));
    await tester.pumpAndSettle();

    expect(thumbnails, 1);
    expect(addToCollection, 1);
    expect(delete, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('video card hover action row hides unavailable actions', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, onTap: () {}, onPlay: () {});

    await hoverCard(tester);

    expect(find.byKey(const Key('video-summary-card-play-1')), findsOneWidget);
    expect(
      find.byKey(const Key('video-summary-card-thumbnails-1')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('video-summary-card-add-collection-1')),
      findsNothing,
    );
    expect(find.byKey(const Key('video-summary-card-delete-1')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
