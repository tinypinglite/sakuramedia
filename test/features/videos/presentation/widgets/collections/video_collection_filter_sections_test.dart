import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/video_collection_filter_sections.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  Future<void> pumpSections(
    WidgetTester tester, {
    required VideoSortField? sortField,
    SortDirection sortDirection = SortDirection.asc,
    required void Function({
      required VideoSortField? field,
      SortDirection? direction,
    })
    onChanged,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Material(
          child: SingleChildScrollView(
            child: VideoCollectionFilterSectionGroup(
              sortField: sortField,
              sortDirection: sortDirection,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('手动顺序下渲染全部字段 chip 且隐藏方向分节', (tester) async {
    await pumpSections(
      tester,
      sortField: null,
      onChanged: ({required field, direction}) {},
    );

    expect(
      find.byKey(const Key('video-collection-sort-manual')),
      findsOneWidget,
    );
    for (final field in VideoSortField.values) {
      expect(
        find.byKey(Key('video-collection-sort-${field.apiValue}')),
        findsOneWidget,
      );
    }
    // 手动顺序固定升序，不展示方向分节。
    expect(find.text('升降序'), findsNothing);
  });

  testWidgets('非手动字段下展示方向分节', (tester) async {
    await pumpSections(
      tester,
      sortField: VideoSortField.duration,
      sortDirection: SortDirection.desc,
      onChanged: ({required field, direction}) {},
    );

    expect(find.text('升降序'), findsOneWidget);
    expect(
      find.byKey(const Key('video-collection-sort-direction-desc')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('video-collection-sort-direction-asc')),
      findsOneWidget,
    );
  });

  testWidgets('点击字段 chip 回传该字段，点击手动顺序回传 null', (tester) async {
    final fields = <VideoSortField?>[];
    await pumpSections(
      tester,
      sortField: null,
      onChanged: ({required field, direction}) => fields.add(field),
    );

    await tester.tap(find.byKey(const Key('video-collection-sort-duration')));
    await tester.tap(find.byKey(const Key('video-collection-sort-manual')));

    expect(fields, <VideoSortField?>[VideoSortField.duration, null]);
  });

  testWidgets('点击方向 chip 回传对应升降序', (tester) async {
    SortDirection? lastDirection;
    await pumpSections(
      tester,
      sortField: VideoSortField.title,
      sortDirection: SortDirection.asc,
      onChanged: ({required field, direction}) => lastDirection = direction,
    );

    await tester.tap(
      find.byKey(const Key('video-collection-sort-direction-desc')),
    );

    expect(lastDirection, SortDirection.desc);
  });

  testWidgets('入口摘要文案：null 为手动顺序，其余取字段标签', (tester) async {
    expect(videoCollectionSortLabel(null), '手动顺序');
    expect(
      videoCollectionSortLabel(VideoSortField.title),
      VideoSortField.title.label,
    );
  });
}
