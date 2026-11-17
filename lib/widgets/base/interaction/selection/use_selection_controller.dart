import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_controller.dart';

/// 创建随当前 widget 生命周期存活的 [SelectionController]。
///
/// [orderedIds] 会在每次手势发生时调用，因此应读取当前数据源而不是捕获某次
/// build 的列表快照。
SelectionController<ID> useSelectionController<ID>({
  required List<ID> Function() orderedIds,
  SelectionPolicy<ID> policy = const SelectionPolicy(),
}) {
  final controller = useMemoized(
    () => SelectionController<ID>(orderedIds: orderedIds, policy: policy),
    const <Object>[],
  );
  useEffect(() => controller.dispose, <Object>[controller]);
  return controller;
}
