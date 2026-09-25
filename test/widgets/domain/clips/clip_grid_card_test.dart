import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_grid_card.dart';

void main() {
  late SessionStore sessionStore;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
  });

  tearDown(() => sessionStore.dispose());

  MediaClipDto buildClip() {
    return MediaClipDto(
      clipId: 1,
      mediaId: 5,
      movieNumber: 'ABC-001',
      startOffsetSeconds: 0,
      endOffsetSeconds: 30,
      title: '高光片段',
      durationSeconds: 30,
      fileSizeBytes: 1024 * 1024,
      coverImage: null,
      streamUrl: '/stream/1.mp4',
      createdAt: DateTime(2026, 9, 20),
    );
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required VoidCallback onTap,
    VoidCallback? onPlay,
    VoidCallback? onMovie,
    VoidCallback? onAddToCollection,
    VoidCallback? onRename,
    VoidCallback? onDelete,
    bool selectionMode = false,
    ValueChanged<bool>? onSelectedChanged,
    double width = 280,
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
                child: ClipGridCard(
                  clip: buildClip(),
                  onTap: onTap,
                  onPlay: onPlay,
                  onOpenMovie: onMovie,
                  onAddToCollection: onAddToCollection,
                  onRename: onRename,
                  onDelete: onDelete,
                  selectionMode: selectionMode,
                  onSelectedChanged: onSelectedChanged,
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
    await gesture.moveTo(tester.getCenter(find.byType(ClipGridCard)));
    await tester.pumpAndSettle();
  }

  testWidgets('clip card keeps the cover clean until hovered', (
    WidgetTester tester,
  ) async {
    var tapped = 0;
    // 卡片取足够宽（测试字体每个字符都是方块，窄卡片会把标题截断）。
    await pumpCard(tester, onTap: () => tapped++, onPlay: () {}, width: 560);

    // 收起态不铺文字，也没有悬停播放键。
    expect(find.text('高光片段'), findsNothing);
    expect(find.textContaining('ABC-001'), findsNothing);
    expect(find.byKey(const Key('clip-grid-card-play-1')), findsNothing);

    await hoverCard(tester);

    expect(find.textContaining('高光片段', findRichText: true), findsOneWidget);
    expect(find.textContaining('ABC-001', findRichText: true), findsOneWidget);
    expect(find.byKey(const Key('clip-grid-card-play-1')), findsOneWidget);
    // 悬停面板铺满卡片宽度（卡片宽 - 面板左右 padding 12×2），不按内容收缩。
    expect(
      tester.getSize(find.byKey(const Key('clip-grid-card-info-1'))).width,
      tester.getSize(find.byType(ClipGridCard)).width - 24,
    );
    expect(tapped, 0);
  });

  testWidgets('clip card hover play button plays without opening the card', (
    WidgetTester tester,
  ) async {
    var tapped = 0;
    var played = 0;
    await pumpCard(
      tester,
      onTap: () => tapped++,
      onPlay: () => played++,
      width: 560,
    );

    await hoverCard(tester);
    await tester.tap(find.byKey(const Key('clip-grid-card-play-1')));
    await tester.pumpAndSettle();

    expect(played, 1);
    expect(tapped, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clip card truncates a long title without overflowing', (
    WidgetTester tester,
  ) async {
    await pumpCard(
      tester,
      onTap: () {},
      onPlay: () {},
      width: 280,
    );

    await hoverCard(tester);

    expect(find.byKey(const Key('clip-grid-card-play-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clip card hover action row triggers each callback', (
    WidgetTester tester,
  ) async {
    var movie = 0;
    var addToCollection = 0;
    var rename = 0;
    var delete = 0;
    await pumpCard(
      tester,
      onTap: () {},
      onMovie: () => movie++,
      onAddToCollection: () => addToCollection++,
      onRename: () => rename++,
      onDelete: () => delete++,
      width: 560,
    );

    await hoverCard(tester);

    await tester.tap(find.byKey(const Key('clip-grid-card-movie-1')));
    await tester.tap(find.byKey(const Key('clip-grid-card-add-collection-1')));
    await tester.tap(find.byKey(const Key('clip-grid-card-rename-1')));
    await tester.tap(find.byKey(const Key('clip-grid-card-delete-1')));
    await tester.pumpAndSettle();

    expect(movie, 1);
    expect(addToCollection, 1);
    expect(rename, 1);
    expect(delete, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clip card hover action row hides unavailable actions', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, onTap: () {}, onPlay: () {}, width: 560);

    await hoverCard(tester);

    expect(find.byKey(const Key('clip-grid-card-play-1')), findsOneWidget);
    expect(find.byKey(const Key('clip-grid-card-movie-1')), findsNothing);
    expect(
      find.byKey(const Key('clip-grid-card-add-collection-1')),
      findsNothing,
    );
    expect(find.byKey(const Key('clip-grid-card-rename-1')), findsNothing);
    expect(find.byKey(const Key('clip-grid-card-delete-1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clip card does not expand while selecting', (
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
    await gesture.moveTo(tester.getCenter(find.byType(ClipGridCard)));
    await tester.pumpAndSettle();

    expect(find.text('高光片段'), findsNothing);
    expect(find.byKey(const Key('clip-grid-card-play-1')), findsNothing);

    await tester.tap(find.byType(ClipGridCard));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });
}
