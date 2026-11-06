import 'package:flutter/widgets.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_controller.dart';

/// 列表多选「选择模式」的 State 适配层。
///
/// 真正的选择状态机、anchor 与修饰键语义在 [SelectionController]。各页面只负责
/// 提供当前有序 id 列表；批量动作和选择栏仍留在页面。
///
/// ```dart
/// class _MyPageState extends State<MyPage>
///     with MultiSelectStateMixin<MyPage, int> {
///   @override
///   List<int> get selectionOrderedIds =>
///       _items.map((item) => item.id).toList(growable: false);
/// }
/// ```
mixin MultiSelectStateMixin<W extends StatefulWidget, ID> on State<W> {
  late final SelectionController<ID> _selectionController =
      SelectionController<ID>(orderedIds: () => selectionOrderedIds);

  /// 当前列表按展示顺序排列的 id；Shift 范围选择只在这里面扩展。
  List<ID> get selectionOrderedIds => <ID>[];

  /// 是否处于选择模式。
  bool get selectionMode => _selectionController.active;

  /// 当前已选中的 id 集合（只读）。
  Set<ID> get selectedIds => _selectionController.selectedIds;

  /// 已选数量。
  int get selectedCount => _selectionController.selectedCount;

  /// [id] 是否被选中。
  bool isSelected(ID id) => _selectionController.isSelected(id);

  /// [allIds] 是否已全部选中（空集合视为「未全选」）。
  bool isAllSelected(Iterable<ID> allIds) =>
      _selectionController.isAllSelected(allIds);

  @override
  void initState() {
    super.initState();
    _selectionController.addListener(_handleSelectionChanged);
  }

  void _handleSelectionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _selectionController
      ..removeListener(_handleSelectionChanged)
      ..dispose();
    super.dispose();
  }

  /// 进入选择模式；可同时选中 [initial]。
  void enterSelection({ID? initial}) {
    _selectionController.enterSelection(initial: initial);
  }

  /// 退出选择模式并清空已选。
  void exitSelection() {
    _selectionController.exitSelection();
  }

  /// 按当前键盘修饰键处理一次卡片点击：Ctrl/Cmd 切换，Shift 范围。
  void handleSelectTap(ID id, {SelectionGesture? gesture}) {
    _selectionController.handleSelectionTap(id, gesture: gesture);
  }

  /// 卡片普通点击入口：非选择态且无修饰键时执行 [onNormalTap]。
  VoidCallback selectionAwareTap(ID id, VoidCallback onNormalTap) =>
      _selectionController.tapHandler(id, onNormalTap);

  /// 选择态卡片的勾选回调。
  ValueChanged<bool> selectionChangedHandler(ID id) =>
      _selectionController.selectedChangedHandler(id);

  /// 移动端长按：进入选择态并选中该项。
  VoidCallback selectionLongPressHandler(ID id) =>
      _selectionController.longPressHandler(id);

  /// 在「全选 [allIds]」与「取消全选」之间切换。
  void toggleSelectAll(Iterable<ID> allIds) {
    _selectionController.toggleSelectAll(allIds);
  }

  void clearSelection() {
    _selectionController.clearSelection();
  }

  void removeSelection(Iterable<ID> ids) {
    _selectionController.removeAll(ids);
  }

  void replaceSelection(Iterable<ID> ids) {
    _selectionController.replaceSelected(ids);
  }
}
