import 'package:material_ui/material_ui.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_category_state.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_kind.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_state.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_status.dart';

DiagnosticItemState _item(DiagnosticItemStatus status, {String key = 'k'}) {
  switch (status) {
    case DiagnosticItemStatus.disabled:
      return DiagnosticItemState(
        kind: DiagnosticItemKind.joyTag,
        itemKey: key,
        displayName: key,
        status: status,
      );
    case DiagnosticItemStatus.notTested:
      return DiagnosticItemState.notTested(
        kind: DiagnosticItemKind.mediaLibrary,
        itemKey: key,
        displayName: key,
      );
    case DiagnosticItemStatus.probing:
      return DiagnosticItemState.probing(
        kind: DiagnosticItemKind.mediaLibrary,
        itemKey: key,
        displayName: key,
      );
    case DiagnosticItemStatus.healthy:
      return DiagnosticItemState.healthy(
        kind: DiagnosticItemKind.mediaLibrary,
        itemKey: key,
        displayName: key,
      );
    case DiagnosticItemStatus.warning:
      return DiagnosticItemState.warning(
        kind: DiagnosticItemKind.mediaLibrary,
        itemKey: key,
        displayName: key,
      );
    case DiagnosticItemStatus.unhealthy:
      return DiagnosticItemState.unhealthy(
        kind: DiagnosticItemKind.mediaLibrary,
        itemKey: key,
        displayName: key,
        cause: 'c',
        fixHint: 'f',
      );
    case DiagnosticItemStatus.blocked:
      return DiagnosticItemState.blocked(
        kind: DiagnosticItemKind.mediaLibrary,
        itemKey: key,
        displayName: key,
        blockedByLabel: 'x',
        summary: 's',
      );
  }
}

DiagnosticCategoryState _cat(List<DiagnosticItemStatus> statuses) {
  return DiagnosticCategoryState(
    label: 'test',
    icon: Icons.circle,
    items: <DiagnosticItemState>[
      for (int i = 0; i < statuses.length; i++) _item(statuses[i], key: 'k$i'),
    ],
  );
}

void main() {
  group('DiagnosticCategoryState.aggregate', () {
    test('空列表 → notTested', () {
      expect(
        _cat(<DiagnosticItemStatus>[]).aggregate,
        DiagnosticItemStatus.notTested,
      );
    });

    test('任一 unhealthy → unhealthy', () {
      expect(
        _cat(<DiagnosticItemStatus>[
          DiagnosticItemStatus.healthy,
          DiagnosticItemStatus.unhealthy,
          DiagnosticItemStatus.warning,
        ]).aggregate,
        DiagnosticItemStatus.unhealthy,
      );
    });

    test('无 unhealthy 有 warning → warning', () {
      expect(
        _cat(<DiagnosticItemStatus>[
          DiagnosticItemStatus.healthy,
          DiagnosticItemStatus.warning,
        ]).aggregate,
        DiagnosticItemStatus.warning,
      );
    });

    test('全 healthy → healthy', () {
      expect(
        _cat(<DiagnosticItemStatus>[
          DiagnosticItemStatus.healthy,
          DiagnosticItemStatus.healthy,
        ]).aggregate,
        DiagnosticItemStatus.healthy,
      );
    });

    test('全 blocked → blocked', () {
      expect(
        _cat(<DiagnosticItemStatus>[
          DiagnosticItemStatus.blocked,
          DiagnosticItemStatus.blocked,
        ]).aggregate,
        DiagnosticItemStatus.blocked,
      );
    });

    test('healthy + blocked 混合 → warning（半通半挡属于告警语义）', () {
      expect(
        _cat(<DiagnosticItemStatus>[
          DiagnosticItemStatus.healthy,
          DiagnosticItemStatus.blocked,
        ]).aggregate,
        DiagnosticItemStatus.warning,
      );
    });

    test('有 probing 且无更强态 → probing', () {
      expect(
        _cat(<DiagnosticItemStatus>[
          DiagnosticItemStatus.probing,
          DiagnosticItemStatus.notTested,
        ]).aggregate,
        DiagnosticItemStatus.probing,
      );
    });

    test('全 disabled → disabled', () {
      expect(
        _cat(<DiagnosticItemStatus>[
          DiagnosticItemStatus.disabled,
          DiagnosticItemStatus.disabled,
        ]).aggregate,
        DiagnosticItemStatus.disabled,
      );
    });

    test('disabled 与其他状态混合时不压低整体状态', () {
      expect(
        _cat(<DiagnosticItemStatus>[
          DiagnosticItemStatus.disabled,
          DiagnosticItemStatus.healthy,
        ]).aggregate,
        DiagnosticItemStatus.healthy,
      );
      expect(
        _cat(<DiagnosticItemStatus>[
          DiagnosticItemStatus.disabled,
          DiagnosticItemStatus.unhealthy,
        ]).aggregate,
        DiagnosticItemStatus.unhealthy,
      );
    });
  });
}
