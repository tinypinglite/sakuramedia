import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_fix_target.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_kind.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_state.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_status.dart';

void main() {
  group('DiagnosticItemState factories', () {
    test('notTested factory 只保留 kind/key/name，其他字段留空', () {
      final state = DiagnosticItemState.notTested(
        kind: DiagnosticItemKind.mediaLibrary,
        itemKey: 'media-library',
        displayName: '媒体库',
      );

      expect(state.status, DiagnosticItemStatus.notTested);
      expect(state.summary, isNull);
      expect(state.cause, isNull);
      expect(state.fixTarget, isNull);
    });

    test('probing factory 落 probing 态', () {
      final state = DiagnosticItemState.probing(
        kind: DiagnosticItemKind.joyTag,
        itemKey: 'joytag',
        displayName: 'JoyTag 推理',
      );
      expect(state.status, DiagnosticItemStatus.probing);
    });

    test('healthy factory 保留 elapsedMs 与 summary', () {
      final state = DiagnosticItemState.healthy(
        kind: DiagnosticItemKind.javdb,
        itemKey: 'javdb',
        displayName: 'JavDB',
        elapsedMs: 42,
        summary: '连通正常',
      );
      expect(state.status, DiagnosticItemStatus.healthy);
      expect(state.elapsedMs, 42);
      expect(state.summary, '连通正常');
    });

    test('unhealthy factory 强制要求 cause/fixHint 两段', () {
      final state = DiagnosticItemState.unhealthy(
        kind: DiagnosticItemKind.downloaderConnectivity,
        itemKey: 'downloader-connectivity-1',
        displayName: 'qB',
        cause: 'auth 失败',
        fixHint: '重填密码',
        fixTarget: const DiagnosticFixTarget.configurationTab(2),
      );
      expect(state.cause, isNotNull);
      expect(state.fixHint, isNotNull);
      expect(state.fixTarget?.configurationTabIndex, 2);
    });

    test('blocked factory 必须给 blockedByLabel，summary 自动兜底', () {
      final state = DiagnosticItemState.blocked(
        kind: DiagnosticItemKind.indexer,
        itemKey: 'indexer',
        displayName: '索引器',
        blockedByLabel: '媒体库',
      );
      expect(state.status, DiagnosticItemStatus.blocked);
      expect(state.blockedByLabel, '媒体库');
      expect(state.summary, contains('媒体库'));
    });
  });

  group('DiagnosticFixTarget', () {
    test('相同 tabIndex 视为相等', () {
      const a = DiagnosticFixTarget.configurationTab(3);
      const b = DiagnosticFixTarget.configurationTab(3);
      const c = DiagnosticFixTarget.configurationTab(4);
      expect(a, equals(b));
      expect(a == c, isFalse);
    });
  });
}
