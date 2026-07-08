import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/videos/video_collection_sort_bar.dart';

void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    required VideoSortField? sortField,
    SortDirection sortDirection = SortDirection.asc,
    required void Function({required VideoSortField? field, SortDirection? direction})
        onChanged,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Material(
          child: VideoCollectionSortBar(
            sortField: sortField,
            sortDirection: sortDirection,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('手动顺序下渲染全部字段 chip 且隐藏方向切换', (tester) async {
    await pumpBar(
      tester,
      sortField: null,
      onChanged: ({required field, direction}) {},
    );

    expect(find.byKey(const Key('video-collection-sort-manual')), findsOneWidget);
    for (final field in VideoSortField.values) {
      expect(
        find.byKey(Key('video-collection-sort-${field.apiValue}')),
        findsOneWidget,
      );
    }
    // 手动顺序固定升序，不展示方向切换。
    expect(
      find.byKey(const Key('video-collection-sort-direction')),
      findsNothing,
    );
  });

  testWidgets('非手动字段下展示方向切换', (tester) async {
    await pumpBar(
      tester,
      sortField: VideoSortField.duration,
      sortDirection: SortDirection.desc,
      onChanged: ({required field, direction}) {},
    );

    expect(
      find.byKey(const Key('video-collection-sort-direction')),
      findsOneWidget,
    );
  });

  testWidgets('点击字段 chip 回传该字段，点击手动顺序回传 null', (tester) async {
    final fields = <VideoSortField?>[];
    await pumpBar(
      tester,
      sortField: null,
      onChanged: ({required field, direction}) => fields.add(field),
    );

    await tester.tap(find.byKey(const Key('video-collection-sort-duration')));
    await tester.tap(find.byKey(const Key('video-collection-sort-manual')));

    expect(fields, <VideoSortField?>[VideoSortField.duration, null]);
  });

  testWidgets('点击方向切换翻转升降序', (tester) async {
    SortDirection? lastDirection;
    await pumpBar(
      tester,
      sortField: VideoSortField.title,
      sortDirection: SortDirection.asc,
      onChanged: ({required field, direction}) => lastDirection = direction,
    );

    await tester.tap(find.byKey(const Key('video-collection-sort-direction')));

    expect(lastDirection, SortDirection.desc);
  });
}
