import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_tag_filter_provider.dart';
import 'package:sakuramedia/widgets/domain/tags/tag_selector_panel.dart';

/// 女优详情的独立标签筛选面板。
///
/// 数据来自该女优的作品标签接口，每个标签的数量已经是当前女优的作品数；
/// 面板不提供搜索或热门标签分组，直接展示全部标签。
class ActorTagFilterPanel extends ConsumerWidget {
  const ActorTagFilterPanel({super.key, required this.actorId});

  final int actorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(actorTagFilterProvider(actorId));
    final notifier = ref.read(actorTagFilterProvider(actorId).notifier);
    return TagSelectorPanel(
      keyPrefix: 'actor-tags',
      selection: state,
      showSearch: false,
      showCloudHeader: false,
      onToggleTag: notifier.toggle,
      onRemoveTag: notifier.remove,
      onClear: notifier.clear,
      onMatchModeChanged: notifier.setMatchMode,
      onRetry: notifier.load,
    );
  }
}
