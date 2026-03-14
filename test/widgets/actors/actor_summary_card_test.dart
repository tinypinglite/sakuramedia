import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/data/actor_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actors/actor_summary_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'actor summary card falls back to name and shows placeholder without image',
    (WidgetTester tester) async {
      final sessionStore = SessionStore.inMemory();
      await sessionStore.saveBaseUrl('https://api.example.com');

      await tester.pumpWidget(
        ChangeNotifierProvider<SessionStore>.value(
          value: sessionStore,
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: ActorSummaryCard(
                actor: const ActorListItemDto(
                  id: 2,
                  javdbId: 'Actor2',
                  name: '桥本有菜',
                  aliasName: '',
                  profileImage: null,
                  isSubscribed: false,
                ),
                onSubscriptionTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('桥本有菜'), findsOneWidget);
      expect(
        find.byKey(const Key('actor-summary-card-placeholder-2')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    },
  );

  testWidgets('actor summary card shows subscribed badge and alias name', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      ChangeNotifierProvider<SessionStore>.value(
        value: sessionStore,
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: ActorSummaryCard(
              actor: const ActorListItemDto(
                id: 1,
                javdbId: 'Actor1',
                name: '三上悠亚',
                aliasName: '三上悠亚 / 鬼头桃菜',
                profileImage: null,
                isSubscribed: true,
              ),
              onSubscriptionTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('三上悠亚 / 鬼头桃菜'), findsOneWidget);
    expect(
      find.byKey(const Key('actor-summary-card-subscription-1')),
      findsOneWidget,
    );

    final bookmarkIcon = tester.widget<Icon>(
      find.byIcon(Icons.favorite_rounded),
    );
    expect(bookmarkIcon.color, AppColors.defaults().subscriptionHeartIcon);
    expect(bookmarkIcon.size, AppComponentTokens.defaults().iconSizeXl);
  });

  testWidgets(
    'actor summary card shows loading indicator while subscription updates',
    (WidgetTester tester) async {
      final sessionStore = SessionStore.inMemory();
      await sessionStore.saveBaseUrl('https://api.example.com');

      await tester.pumpWidget(
        ChangeNotifierProvider<SessionStore>.value(
          value: sessionStore,
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: ActorSummaryCard(
                actor: const ActorListItemDto(
                  id: 3,
                  javdbId: 'Actor3',
                  name: '新有菜',
                  aliasName: '',
                  profileImage: null,
                  isSubscribed: true,
                ),
                onSubscriptionTap: () {},
                isSubscriptionUpdating: true,
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('actor-summary-card-subscription-loading-3')),
        findsOneWidget,
      );
    },
  );
}
