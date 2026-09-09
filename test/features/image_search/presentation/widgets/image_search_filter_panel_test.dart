import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/image_search/data/image_search_target.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/features/image_search/presentation/widgets/actor_selector_dialog.dart';
import 'package:sakuramedia/features/image_search/presentation/widgets/image_search_filter_panel.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';

void main() {
  testWidgets('search range defaults to thumbnails and can switch to plot', (
    WidgetTester tester,
  ) async {
    var filter = const ImageSearchFilterState();

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ImageSearchFilterPanel(
                filterState: filter,
                onChanged: (next) => setState(() => filter = next),
                onSelectActors: () {},
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('搜索素材'), findsOneWidget);
    expect(_button(tester, '缩略图').isSelected, isTrue);
    expect(_button(tester, '剧情图').isSelected, isFalse);

    await tester.tap(find.text('剧情图'));
    await tester.pump();

    expect(filter.searchTarget, ImageSearchTarget.plot);
    expect(_button(tester, '缩略图').isSelected, isFalse);
    expect(_button(tester, '剧情图').isSelected, isTrue);
  });

  testWidgets('actor selector appears only when actor filtering is enabled', (
    WidgetTester tester,
  ) async {
    var filter = const ImageSearchFilterState();

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ImageSearchFilterPanel(
              filterState: filter,
              onChanged: (next) => setState(() => filter = next),
              onSelectActors: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('image-search-filter-select-actors')),
      findsNothing,
    );

    await tester.tap(find.text('仅包含所选'));
    await tester.pump();

    expect(
      find.byKey(const Key('image-search-filter-select-actors')),
      findsOneWidget,
    );
    expect(find.text('请选择至少一位女优'), findsOneWidget);
  });

  testWidgets('desktop actor selector updates its draft before closing', (
    WidgetTester tester,
  ) async {
    const actor = ActorListItemDto(
      id: 7,
      javdbId: 'actor-7',
      name: '测试女优',
      aliasName: '',
      profileImage: null,
      isSubscribed: true,
    );
    var selectedActors = const <ActorListItemDto>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showActorSelectorDialog(
                context,
                actors: const <ActorListItemDto>[actor],
                initialSelectedActors: selectedActors,
                onSelectionChanged: (actors) => selectedActors = actors,
              ),
              child: const Text('打开选择器'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开选择器'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('image-search-actor-option-7')));
    await tester.pump();

    expect(selectedActors, const <ActorListItemDto>[actor]);
    expect(find.text('完成'), findsNothing);

    await tester.tap(find.byKey(const Key('image-search-actor-clear-button')));
    await tester.pump();
    expect(selectedActors, isEmpty);

    await tester.tap(find.byKey(const Key('image-search-actor-close-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('image-search-actor-picker-dialog')),
      findsNothing,
    );
  });

  testWidgets('mobile filter drawer selects actors without stacking a drawer', (
    WidgetTester tester,
  ) async {
    const actor = ActorListItemDto(
      id: 7,
      javdbId: 'actor-7',
      name: '测试女优',
      aliasName: '',
      profileImage: null,
      isSubscribed: true,
    );
    ImageSearchFilterState? appliedFilter;

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                appliedFilter = await showMobileImageSearchFilterDrawer(
                  context,
                  initialFilter: const ImageSearchFilterState(),
                  isSearching: false,
                  loadActors: () async => const <ActorListItemDto>[actor],
                );
              },
              child: const Text('打开筛选'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('仅包含所选'));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('image-search-filter-select-actors')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-image-search-filter-drawer')),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('测试女优'), findsOneWidget);

    expect(find.text('选择已订阅女优'), findsOneWidget);
    await tester.tap(find.byKey(const Key('image-search-actor-option-7')));
    await tester.pump();
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const Key('image-search-actor-checkbox-7')),
          )
          .value,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('image-search-actor-close-button')));
    await tester.pumpAndSettle();

    expect(find.text('已选 1 位'), findsOneWidget);
    await tester.tap(find.byKey(const Key('image-search-filter-apply')));
    await tester.pumpAndSettle();

    expect(appliedFilter?.selectedActorCount, 1);
    expect(
      appliedFilter?.actorFilterMode,
      ImageSearchActorFilterMode.includeSelected,
    );
  });
}

AppButton _button(WidgetTester tester, String label) {
  return tester.widget<AppButton>(find.widgetWithText(AppButton, label));
}
