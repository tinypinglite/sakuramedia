import 'package:flutter/widgets.dart';

/// 列表多选「选择模式」状态机：进入/退出选择、单选切换、全选/取消全选。
///
/// 视频列表页与视频合集详情页此前各写了一份近乎相同的实现，统一收口到这里。
/// 混入到 `State` 上，按选中对象的 id 类型 [ID] 参数化；调用方只需在自己的批量动作
/// 与选择栏里复用这些方法，差异化的批量操作按钮仍留在各页面。
///
/// ```dart
/// class _MyPageState extends State<MyPage>
///     with MultiSelectStateMixin<MyPage, int> { ... }
/// ```
mixin MultiSelectStateMixin<W extends StatefulWidget, ID> on State<W> {
  bool _selectionMode = false;
  final Set<ID> _selectedIds = <ID>{};

  /// 是否处于选择模式。
  bool get selectionMode => _selectionMode;

  /// 当前已选中的 id 集合（只读用途；增删请走下方方法）。
  Set<ID> get selectedIds => _selectedIds;

  /// 已选数量。
  int get selectedCount => _selectedIds.length;

  /// [id] 是否被选中。
  bool isSelected(ID id) => _selectedIds.contains(id);

  /// [allIds] 是否已全部选中（空集合视为「未全选」）。
  bool isAllSelected(Iterable<ID> allIds) {
    final list = allIds is List<ID> ? allIds : allIds.toList(growable: false);
    return list.isNotEmpty && list.every(_selectedIds.contains);
  }

  /// 进入选择模式。
  void enterSelection() {
    setState(() => _selectionMode = true);
  }

  /// 退出选择模式并清空已选。
  void exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  /// 切换单个 [id] 的选中状态。
  void toggleSelect(ID id) {
    setState(() {
      if (!_selectedIds.add(id)) {
        _selectedIds.remove(id);
      }
    });
  }

  /// 在「全选 [allIds]」与「清空」之间切换。
  void toggleSelectAll(Iterable<ID> allIds) {
    setState(() {
      if (isAllSelected(allIds)) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(allIds);
      }
    });
  }
}
