import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/playlists/playlist_banner_card.dart';

void main() {
  testWidgets('playlist banner card renders blurred background and title', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    addTearDown(sessionStore.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<SessionStore>.value(
        value: sessionStore,
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
    expect(find.byType(ImageFiltered), findsNWidgets(2));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('playlist banner card exposes placeholder state and tap', (
    WidgetTester tester,
  ) async {
    var tapped = false;
    final sessionStore = SessionStore.inMemory();
    addTearDown(sessionStore.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<SessionStore>.value(
        value: sessionStore,
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

    await tester.tap(find.byType(PlaylistBannerCard));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
