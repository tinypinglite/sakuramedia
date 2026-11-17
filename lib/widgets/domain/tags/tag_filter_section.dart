import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_provider.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_scope.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/domain/tags/tag_selector_panel.dart';

/// 把标签选择接进筛选面板的「标签」分节。
///
/// 只负责把 [scope] 对应的选择状态接到 [TagSelectorPanel]；标签数据在面板
/// 第一次打开时才加载（scope 用 `preload: false`）。筛选面板里走精简形态：
/// 搜索框默认收起、标签收起态只展示前 5 个、展开后显示全部。
class TagFilterSection extends ConsumerWidget {
  const TagFilterSection({super.key, required this.scope});

  final TagSelectionScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selection = ref.watch(tagSelectionProvider(scope));
    final notifier = ref.read(tagSelectionProvider(scope).notifier);
    return TagSelectorPanel(
      selection: selection,
      title: l10n.widgetTagFilterTitle,
      collapsibleSearch: true,
      collapsedTagCount: 5,
      showTagCounts: false,
      onToggleTag: notifier.toggle,
      onRemoveTag: notifier.remove,
      onClear: notifier.clear,
      onQueryChanged: notifier.setQuery,
      onToggleExpanded: notifier.toggleExpanded,
      onMatchModeChanged: notifier.setMatchMode,
      onRetry: () => unawaited(notifier.retry()),
    );
  }
}
