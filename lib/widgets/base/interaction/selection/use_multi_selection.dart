import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// [MultiSelectStateMixin] 的 Hook 版本：选择模式 + 按 id 多选。
///
/// 页面已有独立选中集合（例如由 provider 持有）时，可只使用
/// [selectionMode]、[enter] 与 [exit]。
class MultiSelection<ID> {
  MultiSelection._(this._mode, this._ids);

  final ValueNotifier<bool> _mode;
  final ValueNotifier<Set<ID>> _ids;

  bool get selectionMode => _mode.value;

  Set<ID> get selectedIds => _ids.value;

  int get selectedCount => _ids.value.length;

  bool isSelected(ID id) => _ids.value.contains(id);

  bool isAllSelected(Iterable<ID> allIds) {
    final ids = allIds.toList(growable: false);
    return ids.isNotEmpty && ids.every(_ids.value.contains);
  }

  void enter([ID? initial]) {
    _mode.value = true;
    if (initial != null) {
      _ids.value = {..._ids.value, initial};
    }
  }

  void exit() {
    _mode.value = false;
    _ids.value = <ID>{};
  }

  void toggle(ID id) {
    final next = {..._ids.value};
    if (!next.remove(id)) {
      next.add(id);
    }
    _ids.value = next;
  }

  void toggleAll(Iterable<ID> allIds) {
    final ids = allIds.toList(growable: false);
    final next = {..._ids.value};
    if (ids.isNotEmpty && ids.every(next.contains)) {
      next.removeAll(ids);
    } else {
      next.addAll(ids);
    }
    _ids.value = next;
  }
}

/// 创建随当前 widget 生命周期存活的多选状态。
MultiSelection<ID> useMultiSelection<ID>() =>
    MultiSelection._(useState(false), useState(<ID>{}));
