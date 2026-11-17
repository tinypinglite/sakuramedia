import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show IconData;
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_state.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_status.dart';

/// 一组诊断项在页面上的分组渲染单位。
///
/// 汇总规则（[aggregate]）：
/// - 有任意一项 unhealthy → unhealthy
/// - 否则有 warning → warning
/// - 否则有 probing → probing
/// - 否则全部 healthy → healthy
/// - 否则全部 blocked → blocked
/// - 其他（含 notTested）→ notTested
@immutable
class DiagnosticCategoryState {
  const DiagnosticCategoryState({
    required this.label,
    required this.icon,
    required this.items,
  });

  final String label;
  final IconData icon;
  final List<DiagnosticItemState> items;

  DiagnosticItemStatus get aggregate =>
      mergeDiagnosticStatuses(items.map((item) => item.status));
}
