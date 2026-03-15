import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_hero_card.dart';

void main() {
  late SessionStore sessionStore;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
  });

  testWidgets('movie detail hero card fills the main image height', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildApp(sessionStore: sessionStore));

    final maskedImages = tester.widgetList<MaskedImage>(
      find.byType(MaskedImage),
    );
    final mainImage = maskedImages.firstWhere(
      (widget) => widget.url == '/covers/main.jpg',
    );

    expect(mainImage.fit, BoxFit.fitHeight);
  });

  testWidgets('movie detail hero card uses horizontal-only content padding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildApp(sessionStore: sessionStore));

    final paddings = tester.widgetList<Padding>(
      find.descendant(
        of: find.byType(MovieDetailHeroCard),
        matching: find.byType(Padding),
      ),
    );

    final contentPadding = paddings
        .map((widget) => widget.padding)
        .whereType<EdgeInsets>()
        .firstWhere((padding) => padding.left == 16 && padding.right == 16);

    expect(contentPadding.top, 0);
    expect(contentPadding.bottom, 0);
  });

  testWidgets('movie detail hero card shows subscription as heart icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<SessionStore>.value(
        value: sessionStore,
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              child: MovieDetailHeroCard(
                height: 420,
                mainImageKey: 'cover',
                mainImageUrl: '/covers/main.jpg',
                thinCoverUrl: '/covers/thin.jpg',
                canPlay: true,
                isSubscribed: true,
                isCollection: false,
                onPlayTap: null,
                onSubscriptionTap: null,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('已收藏'), findsNothing);
    expect(
      find.byKey(const Key('movie-detail-hero-subscription-icon')),
      findsOneWidget,
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.favorite_rounded));
    expect(icon.color, AppColors.defaults().subscriptionHeartIcon);
    expect(icon.size, AppComponentTokens.defaults().iconSizeXl);
  });

  testWidgets(
    'movie detail hero card shows outlined subscription icon and handles tap when unsubscribed',
    (WidgetTester tester) async {
      var tapped = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<SessionStore>.value(
          value: sessionStore,
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: SizedBox(
                width: 1200,
                child: MovieDetailHeroCard(
                  height: 420,
                  mainImageKey: 'cover',
                  mainImageUrl: '/covers/main.jpg',
                  thinCoverUrl: '/covers/thin.jpg',
                  canPlay: true,
                  isSubscribed: false,
                  isCollection: false,
                  onPlayTap: null,
                  onSubscriptionTap: () {
                    tapped = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('movie-detail-hero-subscription-icon')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('movie-detail-hero-subscription-icon')),
      );
      await tester.pump();

      expect(tapped, isTrue);
    },
  );

  testWidgets('movie detail hero card invokes play callback from center icon', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      ChangeNotifierProvider<SessionStore>.value(
        value: sessionStore,
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              child: MovieDetailHeroCard(
                height: 420,
                mainImageKey: 'cover',
                mainImageUrl: '/covers/main.jpg',
                thinCoverUrl: '/covers/thin.jpg',
                canPlay: true,
                isSubscribed: false,
                isCollection: false,
                onPlayTap: () {
                  tapped = true;
                },
                onSubscriptionTap: null,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('movie-detail-hero-play-button')));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('movie detail hero card uses global hero play icon token', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<SessionStore>.value(
        value: sessionStore,
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              child: MovieDetailHeroCard(
                height: 420,
                mainImageKey: 'cover',
                mainImageUrl: '/covers/main.jpg',
                thinCoverUrl: '/covers/thin.jpg',
                canPlay: true,
                isSubscribed: false,
                isCollection: false,
                onPlayTap: () {},
                onSubscriptionTap: null,
              ),
            ),
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded));
    expect(icon.size, AppComponentTokens.defaults().iconSize4xl);
  });

  testWidgets(
    'movie detail hero card hides center play icon when unavailable',
    (WidgetTester tester) async {
      await tester.pumpWidget(_buildApp(sessionStore: sessionStore));

      expect(
        find.byKey(const Key('movie-detail-hero-play-button')),
        findsNothing,
      );
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    },
  );
}

Widget _buildApp({required SessionStore sessionStore}) {
  return ChangeNotifierProvider<SessionStore>.value(
    value: sessionStore,
    child: MaterialApp(
      theme: sakuraThemeData,
      home: Scaffold(
        body: SizedBox(
          width: 1200,
          child: MovieDetailHeroCard(
            height: 420,
            mainImageKey: 'cover',
            mainImageUrl: '/covers/main.jpg',
            thinCoverUrl: '/covers/thin.jpg',
            canPlay: true,
            isSubscribed: false,
            isCollection: false,
            onPlayTap: null,
            onSubscriptionTap: null,
          ),
        ),
      ),
    ),
  );
}
