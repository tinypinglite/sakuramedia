import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/domain/playlists/playlist_banner_card.dart';

void main() {
  testWidgets('playlist banner card uses a low-resolution static background', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    addTearDown(sessionStore.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: PlaylistBannerCard(
              title: '我的收藏',
              coverImageUrl: 'https://example.com/cover.jpg',
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('我的收藏'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
    final image = tester.widget<MaskedImage>(find.byType(MaskedImage));
    expect(image.memCacheWidth, 32);
    expect(image.filterQuality, FilterQuality.high);
    expect(image.animateReveal, isFalse);
  });

  testWidgets('playlist banner card exposes placeholder state and tap', (
    WidgetTester tester,
  ) async {
    var tapped = false;
    final sessionStore = SessionStore.inMemory();
    addTearDown(sessionStore.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: PlaylistBannerCard(
              title: '空列表',
              coverImageUrl: null,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('playlist-banner-placeholder')),
      findsOneWidget,
    );
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.byType(MaskedImage), findsNothing);

    await tester.tap(find.byType(PlaylistBannerCard));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
