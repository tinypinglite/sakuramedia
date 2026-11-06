import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 一次选择点击的意图。
///
/// - [plain]：普通点击；选择态内切换单个条目，选择态外执行卡片原动作。
/// - [toggle]：Ctrl / Cmd 点击；进入选择态并切换单个条目。
/// - [range]：Shift 点击；进入选择态并从 anchor 扩展到目标条目。
enum SelectionGesture { plain, toggle, range }

/// 读取当前键盘修饰键，得到统一的选择点击意图。
///
/// macOS 使用 Cmd（同时兼容 Ctrl），Windows 使用 Ctrl。其他平台没有桌面修饰键
/// 习惯，统一返回 [SelectionGesture.plain]。
SelectionGesture resolveSelectionGesture() {
  if (defaultTargetPlatform != TargetPlatform.macOS &&
      defaultTargetPlatform != TargetPlatform.windows) {
    return SelectionGesture.plain;
  }
  final keyboard = HardwareKeyboard.instance;
  if (keyboard.isShiftPressed) {
    return SelectionGesture.range;
  }
  final togglePressed = defaultTargetPlatform == TargetPlatform.macOS
      ? keyboard.isMetaPressed || keyboard.isControlPressed
      : keyboard.isControlPressed;
  return togglePressed ? SelectionGesture.toggle : SelectionGesture.plain;
}

/// 选择集合的业务约束。
@immutable
class SelectionPolicy<ID> {
  const SelectionPolicy({this.canSelect});

  /// 返回 false 时不允许把 [id] 加进选择集合；移除不受限制。
  ///
  /// 用于重复媒体组「至少保留一个文件」这类局部规则。范围选择会按顺序过滤，
  /// 因此被拒绝的条目不会进入最终集合。
  final bool Function(ID id, Set<ID> selected)? canSelect;
}

/// 列表多选的不可变状态：选择态、选中集合、范围选择 anchor。
@immutable
class SelectionState<ID> {
  SelectionState({this.active = false, Set<ID>? selected, this.anchor})
    : selected = Set<ID>.unmodifiable(selected ?? <ID>{});

  final bool active;
  final Set<ID> selected;

  /// 上一次普通/Ctrl 点击的条目；Shift 范围选择不会移动它。
  final ID? anchor;

  int get count => selected.length;

  bool get hasSelection => selected.isNotEmpty;

  bool isSelected(ID id) => selected.contains(id);

  bool isAllSelected(Iterable<ID> ids) {
    final list = ids is List<ID> ? ids : ids.toList(growable: false);
    return list.isNotEmpty && list.every(selected.contains);
  }

  SelectionState<ID> activate({ID? initial, SelectionPolicy<ID>? policy}) {
    final next = <ID>{...selected};
    if (initial != null && _allows(initial, next, policy)) {
      next.add(initial);
    }
    return SelectionState<ID>(
      active: true,
      selected: next,
      anchor: initial ?? anchor,
    );
  }

  SelectionState<ID> deactivate() => SelectionState<ID>();

  SelectionState<ID> toggle(ID id, {SelectionPolicy<ID>? policy}) {
    final next = <ID>{...selected};
    if (next.remove(id)) {
      return SelectionState<ID>(
        active: active,
        selected: next,
        anchor: anchor == id ? null : anchor,
      );
    }
    if (!_allows(id, next, policy)) {
      return this;
    }
    next.add(id);
    return SelectionState<ID>(active: active, selected: next, anchor: id);
  }

  /// 从 [anchor] 到 [id] 的闭区间范围选择。
  ///
  /// 范围是追加式的：保留已有勾选，不静默清空用户的选择。anchor 缺失或不在
  /// 当前有序列表里时退化为只选中目标条目。
  SelectionState<ID> extendTo(
    ID id,
    List<ID> orderedIds, {
    SelectionPolicy<ID>? policy,
  }) {
    final anchorId = anchor;
    final start = anchorId == null ? -1 : orderedIds.indexOf(anchorId);
    final end = orderedIds.indexOf(id);
    if (start < 0 || end < 0) {
      final next = <ID>{...selected};
      if (_allows(id, next, policy)) {
        next.add(id);
      }
      return SelectionState<ID>(active: true, selected: next, anchor: id);
    }
    final lower = math.min(start, end);
    final upper = math.max(start, end);
    final next = <ID>{...selected};
    for (final candidate in orderedIds.sublist(lower, upper + 1)) {
      if (_allows(candidate, next, policy)) {
        next.add(candidate);
      }
    }
    return SelectionState<ID>(active: true, selected: next, anchor: anchorId);
  }

  /// 在「全部选中 [ids]」与「移除这些 id」之间切换。
  SelectionState<ID> toggleAll(
    Iterable<ID> ids, {
    SelectionPolicy<ID>? policy,
  }) {
    final list = ids.toList(growable: false);
    final next = <ID>{...selected};
    final allSelected = list.isNotEmpty && list.every(next.contains);
    if (allSelected) {
      next.removeAll(list);
    } else {
      for (final id in list) {
        if (_allows(id, next, policy)) {
          next.add(id);
        }
      }
    }
    final nextAnchor = allSelected && anchor != null && list.contains(anchor)
        ? null
        : anchor;
    return SelectionState<ID>(active: true, selected: next, anchor: nextAnchor);
  }

  SelectionState<ID> clear() => SelectionState<ID>(active: active);

  SelectionState<ID> removeAll(Iterable<ID> ids) {
    final targets = ids.toSet();
    if (targets.isEmpty || selected.isEmpty) return this;
    final next = <ID>{...selected}..removeAll(targets);
    if (next.length == selected.length) return this;
    return SelectionState<ID>(
      active: active,
      selected: next,
      anchor: anchor != null && targets.contains(anchor) ? null : anchor,
    );
  }

  SelectionState<ID> retainOnly(Iterable<ID> ids) {
    final keep = ids.toSet();
    final next = selected.intersection(keep);
    if (next.length == selected.length) return this;
    return SelectionState<ID>(
      active: active,
      selected: next,
      anchor: anchor != null && keep.contains(anchor) ? anchor : null,
    );
  }

  SelectionState<ID> replaceSelected(Iterable<ID> ids) {
    final next = ids.toSet();
    return SelectionState<ID>(
      active: active,
      selected: next,
      anchor: anchor != null && next.contains(anchor) ? anchor : null,
    );
  }

  SelectionState<ID> applyGesture(
    ID id,
    SelectionGesture gesture,
    List<ID> orderedIds, {
    SelectionPolicy<ID>? policy,
  }) {
    return switch (gesture) {
      SelectionGesture.range => extendTo(id, orderedIds, policy: policy),
      SelectionGesture.toggle => activate().toggle(id, policy: policy),
      SelectionGesture.plain => active ? toggle(id, policy: policy) : this,
    };
  }

  static bool _allows<ID>(
    ID id,
    Set<ID> selected,
    SelectionPolicy<ID>? policy,
  ) {
    final canSelect = policy?.canSelect;
    return canSelect == null || canSelect(id, selected);
  }

  @override
  bool operator ==(Object other) {
    return other is SelectionState<ID> &&
        other.active == active &&
        other.anchor == anchor &&
        setEquals(other.selected, selected);
  }

  @override
  int get hashCode =>
      Object.hash(active, anchor, Object.hashAllUnordered(selected));
}

/// 页面/列表级选择控制器：持有状态、anchor 和有序 id 来源。
///
/// 每个列表一个实例，不跨页面共享。Provider 页面可以直接复用
/// [SelectionState] 的纯状态转换；页面本地状态使用本 controller。
class SelectionController<ID> extends ChangeNotifier {
  SelectionController({
    required this.orderedIds,
    this.policy = const SelectionPolicy(),
    SelectionState<ID>? initialState,
  }) : _state = initialState ?? SelectionState<ID>();

  final List<ID> Function() orderedIds;
  final SelectionPolicy<ID> policy;

  SelectionState<ID> _state;

  SelectionState<ID> get state => _state;

  bool get active => _state.active;

  Set<ID> get selectedIds => _state.selected;

  int get selectedCount => _state.count;

  bool isSelected(ID id) => _state.isSelected(id);

  bool isAllSelected(Iterable<ID> ids) => _state.isAllSelected(ids);

  void enterSelection({ID? initial}) {
    _setState(_state.activate(initial: initial, policy: policy));
  }

  void exitSelection() {
    _setState(_state.deactivate());
  }

  void toggleSelect(ID id) {
    _setState(_state.toggle(id, policy: policy));
  }

  void handleSelectionTap(ID id, {SelectionGesture? gesture}) {
    _setState(
      _state.applyGesture(
        id,
        gesture ?? resolveSelectionGesture(),
        orderedIds(),
        policy: policy,
      ),
    );
  }

  void toggleSelectAll(Iterable<ID> ids) {
    _setState(_state.toggleAll(ids, policy: policy));
  }

  void clearSelection() {
    _setState(_state.clear());
  }

  void removeAll(Iterable<ID> ids) {
    _setState(_state.removeAll(ids));
  }

  void retainOnly(Iterable<ID> ids) {
    _setState(_state.retainOnly(ids));
  }

  void replaceSelected(Iterable<ID> ids) {
    _setState(_state.replaceSelected(ids));
  }

  /// 卡片普通点击入口：选择态内切换；带修饰键时进入选择态并选择；
  /// 否则执行卡片原动作。
  VoidCallback tapHandler(ID id, VoidCallback onNormalTap) {
    return () {
      final gesture = resolveSelectionGesture();
      if (gesture != SelectionGesture.plain) {
        handleSelectionTap(id, gesture: gesture);
        return;
      }
      if (_state.active) {
        handleSelectionTap(id, gesture: SelectionGesture.plain);
        return;
      }
      onNormalTap();
    };
  }

  /// 选择态卡片的勾选回调；忽略卡片传入的目标 bool，以 controller 为准。
  ValueChanged<bool> selectedChangedHandler(ID id) {
    return (_) => handleSelectionTap(id);
  }

  /// 移动端长按入口：未进入选择态时进入并选中该项；已进入时切换。
  VoidCallback longPressHandler(ID id) {
    return () {
      if (_state.active) {
        handleSelectionTap(id, gesture: SelectionGesture.plain);
      } else {
        enterSelection(initial: id);
      }
    };
  }

  void _setState(SelectionState<ID> next) {
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }
}

/// Provider 页面的轻量手势适配：状态仍在 provider，点击语义与
/// [SelectionController.tapHandler] 一致。
abstract final class SelectionInteraction {
  static VoidCallback tap({
    required bool active,
    required ValueChanged<SelectionGesture> onGesture,
    required VoidCallback onNormalTap,
  }) {
    return () {
      final gesture = resolveSelectionGesture();
      if (gesture != SelectionGesture.plain || active) {
        onGesture(gesture);
        return;
      }
      onNormalTap();
    };
  }
}
