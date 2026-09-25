import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_card.dart';

void main() {
  late SessionStore sessionStore;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
  });

  tearDown(() => sessionStore.dispose());

  MomentListItem buildMoment({int mediaId = 5, int? videoItemId}) {
    return MomentListItem(
      pointId: 10,
      mediaId: mediaId,
      movieNumber: videoItemId == null ? 'ABC-001' : null,
      videoItemId: videoItemId,
      thumbnailId: 1,
      offsetSeconds: 90,
      image: null,
    );
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required MomentListItem item,
    VoidCallback? onTap,
    VoidCallback? onPlay,
    VoidCallback? onMovie,
    VoidCallback? onAddToCollection,
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
                height: 175,
                child: MomentCard(
                  item: item,
                  onTap: onTap,
                  onPlay: onPlay,
                  onOpenMovie: onMovie,
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
    );
  }

  Future<void> hoverCard(WidgetTester tester, int pointId) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(
      tester.getCenter(find.byKey(Key('moment-card-$pointId'))),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('moment card keeps the cover clean until hovered', (
    WidgetTester tester,
  ) async {
    var tapped = 0;
    // 卡片取足够宽（测试字体每个字符都是方块，窄卡片会把信息截断）。
    await pumpCard(
      tester,
      item: buildMoment(),
      onTap: () => tapped++,
      onPlay: () {},
      width: 560,
    );

    expect(find.text('ABC-001'), findsNothing);
    expect(find.textContaining('01:30'), findsNothing);
    expect(find.byKey(const Key('moment-card-play-10')), findsNothing);

    await hoverCard(tester, 10);

    expect(find.textContaining('ABC-001', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('JAV · 01:30', findRichText: true),
      findsOneWidget,
    );
    expect(find.byKey(const Key('moment-card-play-10')), findsOneWidget);
    // 悬停面板铺满卡片宽度（卡片宽 - 面板左右 padding 12×2），不按内容收缩。
    expect(
      tester.getSize(find.byKey(const Key('moment-card-info-10'))).width,
      tester.getSize(find.byType(MomentCard)).width - 24,
    );
    expect(tapped, 0);
  });

  testWidgets('moment card hover play button plays without opening preview', (
    WidgetTester tester,
  ) async {
    var tapped = 0;
    var played = 0;
    await pumpCard(
      tester,
      item: buildMoment(),
      onTap: () => tapped++,
      onPlay: () => played++,
      width: 560,
    );

    await hoverCard(tester, 10);
    await tester.tap(find.byKey(const Key('moment-card-play-10')));
    await tester.pumpAndSettle();

    expect(played, 1);
    expect(tapped, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('moment card marks a deleted source in the hover panel', (
    WidgetTester tester,
  ) async {
    await pumpCard(
      tester,
      item: buildMoment(mediaId: 0),
      onTap: () {},
      onPlay: () {},
      width: 560,
    );

    await hoverCard(tester, 10);

    expect(
      find.textContaining('来源已删除', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('moment card with a deleted source hides play and never overflows', (
    WidgetTester tester,
  ) async {
    await pumpCard(
      tester,
      item: buildMoment(mediaId: 0),
      onTap: () {},
      onPlay: () {},
    );

    await hoverCard(tester, 10);

    expect(find.byKey(const Key('moment-card-play-10')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('moment card does not expand while selecting', (
    WidgetTester tester,
  ) async {
    var selected = 0;
    await pumpCard(
      tester,
      item: buildMoment(),
      onTap: () {},
      onPlay: () {},
      selectionMode: true,
      onSelectedChanged: (_) => selected++,
    );

    await hoverCard(tester, 10);

    expect(find.text('ABC-001'), findsNothing);
    expect(find.byKey(const Key('moment-card-play-10')), findsNothing);

    await tester.tap(find.byType(MomentCard));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('moment card hover action row triggers each callback', (
    WidgetTester tester,
  ) async {
    var movie = 0;
    var addToCollection = 0;
    var delete = 0;
    await pumpCard(
      tester,
      item: buildMoment(),
      onTap: () {},
      onPlay: () {},
      onMovie: () => movie++,
      onAddToCollection: () => addToCollection++,
      onDelete: () => delete++,
      width: 560,
    );

    await hoverCard(tester, 10);
    await tester.tap(find.byKey(const Key('moment-card-movie-10')));
    await tester.tap(find.byKey(const Key('moment-card-add-collection-10')));
    await tester.tap(find.byKey(const Key('moment-card-delete-10')));
    await tester.pumpAndSettle();

    expect(movie, 1);
    expect(addToCollection, 1);
    expect(delete, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('moment card hover action row hides unavailable actions', (
    WidgetTester tester,
  ) async {
    await pumpCard(
      tester,
      item: buildMoment(),
      onTap: () {},
      onPlay: () {},
      width: 560,
    );

    await hoverCard(tester, 10);

    expect(find.byKey(const Key('moment-card-movie-10')), findsNothing);
    expect(
      find.byKey(const Key('moment-card-add-collection-10')),
      findsNothing,
    );
    expect(find.byKey(const Key('moment-card-delete-10')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
