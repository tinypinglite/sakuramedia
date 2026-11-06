import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_glass_list_header.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/pump_with_providers.dart';

void main() {
  testWidgets('筛选菜单应用未归类条件并可重置', (tester) async {
    var state = VideoFilterState.initial;
    await _pumpHeader(tester, state: state, onChanged: (next) => state = next);

    await tester.tap(find.byKey(const Key('videos-filter-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(_popoverText('videos-filter-popover', '未加入合集'));
    await tester.pumpAndSettle();

    expect(state.uncollected, isTrue);
    expect(state.sortField, VideoSortField.createdAt);
    expect(state.sortDirection, SortDirection.desc);
    expect(find.byKey(const Key('videos-filter-popover')), findsOne);

    await tester.tap(find.byKey(const Key('videos-filter-reset')));
    await tester.pumpAndSettle();

    expect(state.hasActiveFilters, isFalse);
    expect(state.sortField, VideoSortField.createdAt);
    expect(state.sortDirection, SortDirection.desc);
  });

  testWidgets('排序菜单更新字段和方向', (tester) async {
    var state = VideoFilterState.initial;
    await _pumpHeader(tester, state: state, onChanged: (next) => state = next);

    await tester.tap(find.byKey(const Key('videos-sort-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(_popoverText('videos-sort-popover', '标题'));
    await tester.pumpAndSettle();

    expect(state.sortField, VideoSortField.title);
    expect(state.sortDirection, SortDirection.desc);
    expect(find.byKey(const Key('videos-sort-popover')), findsOne);

    await tester.tap(_popoverText('videos-sort-popover', '升序'));
    await tester.pumpAndSettle();

    expect(state.sortField, VideoSortField.title);
    expect(state.sortDirection, SortDirection.asc);
  });

  testWidgets('选择入口只在可进入多选时显示', (tester) async {
    var entered = false;
    await _pumpHeader(
      tester,
      state: VideoFilterState.initial,
      onChanged: (_) {},
      onEnterSelection: () => entered = true,
    );

    await tester.tap(find.byKey(const Key('videos-enter-selection-button')));
    expect(entered, isTrue);

    await _pumpHeader(
      tester,
      state: VideoFilterState.initial,
      onChanged: (_) {},
    );
    expect(
      find.byKey(const Key('videos-enter-selection-button')),
      findsNothing,
    );
  });
}

Finder _popoverText(String popoverKey, String text) {
  return find.descendant(
    of: find.byKey(Key(popoverKey)),
    matching: find.text(text),
  );
}

Future<void> _pumpHeader(
  WidgetTester tester, {
  required VideoFilterState state,
  required ValueChanged<VideoFilterState> onChanged,
  VoidCallback? onEnterSelection,
}) {
  return pumpWithProviders(
    tester,
    home: _VideoGlassListHeaderHarness(
      initialState: state,
      onChanged: onChanged,
      onEnterSelection: onEnterSelection,
    ),
    theme: sakuraDesktopThemeData,
    physicalSize: const Size(1100, 700),
  );
}

class _VideoGlassListHeaderHarness extends StatefulWidget {
  const _VideoGlassListHeaderHarness({
    required this.initialState,
    required this.onChanged,
    this.onEnterSelection,
  });

  final VideoFilterState initialState;
  final ValueChanged<VideoFilterState> onChanged;
  final VoidCallback? onEnterSelection;

  @override
  State<_VideoGlassListHeaderHarness> createState() =>
      _VideoGlassListHeaderHarnessState();
}

class _VideoGlassListHeaderHarnessState
    extends State<_VideoGlassListHeaderHarness> {
  late VideoFilterState _state;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 900,
            child: VideoGlassListHeader(
              filterState: _state,
              total: 128,
              filterUpdate: const FilterUpdateState.idle(),
              hasPreviousFilterItems: true,
              onFilterChanged: (next) {
                setState(() => _state = next);
                widget.onChanged(next);
              },
              onRetryFilter: () {},
              onEnterSelection: widget.onEnterSelection,
            ),
          ),
        ),
      ),
    );
  }
}
