import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_fix_target.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_kind.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_status.dart';

/// 单个诊断项在 UI 上的一份完整快照。
///
/// 不可变；每次状态推进都产出一份新的 [DiagnosticItemState]。
@immutable
class DiagnosticItemState {
  const DiagnosticItemState({
    required this.kind,
    required this.itemKey,
    required this.displayName,
    required this.status,
    this.elapsedMs,
    this.summary,
    this.cause,
    this.fixHint,
    this.fixTarget,
    this.blockedByLabel,
  });

  final DiagnosticItemKind kind;

  /// 稳定 key，用于 widget key + 测试锚点。同一个 kind 下多个实例（例如多个下载器）
  /// 必须区分开，通常拼接 id 或者 index，例如 `downloader-connectivity-3`。
  final String itemKey;

  /// 面向用户展示的行名，例如「qBittorrent · 家庭 NAS」。
  final String displayName;

  final DiagnosticItemStatus status;

  /// 探针执行耗时（毫秒）。
  final int? elapsedMs;

  /// 状态短句；不同 status 语义不同：
  /// - healthy: 例如「qBittorrent 5.0.4 · 30ms」
  /// - unhealthy: 例如「连接超时」
  /// - blocked: 例如「等待媒体库配置就绪」
  final String? summary;

  /// 两段展开：哪坏了。
  final String? cause;

  /// 两段展开：怎么改。
  final String? fixHint;

  final DiagnosticFixTarget? fixTarget;

  /// blocked 态下用来告诉用户「被谁挡住」，例如 "媒体库"。
  final String? blockedByLabel;

  factory DiagnosticItemState.notTested({
    required DiagnosticItemKind kind,
    required String itemKey,
    required String displayName,
  }) {
    return DiagnosticItemState(
      kind: kind,
      itemKey: itemKey,
      displayName: displayName,
      status: DiagnosticItemStatus.notTested,
    );
  }

  factory DiagnosticItemState.probing({
    required DiagnosticItemKind kind,
    required String itemKey,
    required String displayName,
  }) {
    return DiagnosticItemState(
      kind: kind,
      itemKey: itemKey,
      displayName: displayName,
      status: DiagnosticItemStatus.probing,
    );
  }

  factory DiagnosticItemState.healthy({
    required DiagnosticItemKind kind,
    required String itemKey,
    required String displayName,
    int? elapsedMs,
    String? summary,
  }) {
    return DiagnosticItemState(
      kind: kind,
      itemKey: itemKey,
      displayName: displayName,
      status: DiagnosticItemStatus.healthy,
      elapsedMs: elapsedMs,
      summary: summary,
    );
  }

  factory DiagnosticItemState.warning({
    required DiagnosticItemKind kind,
    required String itemKey,
    required String displayName,
    int? elapsedMs,
    String? summary,
    String? cause,
    String? fixHint,
    DiagnosticFixTarget? fixTarget,
  }) {
    return DiagnosticItemState(
      kind: kind,
      itemKey: itemKey,
      displayName: displayName,
      status: DiagnosticItemStatus.warning,
      elapsedMs: elapsedMs,
      summary: summary,
      cause: cause,
      fixHint: fixHint,
      fixTarget: fixTarget,
    );
  }

  factory DiagnosticItemState.unhealthy({
    required DiagnosticItemKind kind,
    required String itemKey,
    required String displayName,
    int? elapsedMs,
    String? summary,
    required String cause,
    required String fixHint,
    DiagnosticFixTarget? fixTarget,
  }) {
    return DiagnosticItemState(
      kind: kind,
      itemKey: itemKey,
      displayName: displayName,
      status: DiagnosticItemStatus.unhealthy,
      elapsedMs: elapsedMs,
      summary: summary,
      cause: cause,
      fixHint: fixHint,
      fixTarget: fixTarget,
    );
  }

  /// 前置依赖未通过；`blockedByLabel` 必填，让 UI 能说清「被谁挡住」。
  factory DiagnosticItemState.blocked({
    required DiagnosticItemKind kind,
    required String itemKey,
    required String displayName,
    required String blockedByLabel,
    String? summary,
  }) {
    assert(
      blockedByLabel.isNotEmpty,
      'blocked 态必须给出 blockedByLabel，否则用户看不到「被谁挡住」',
    );
    return DiagnosticItemState(
      kind: kind,
      itemKey: itemKey,
      displayName: displayName,
      status: DiagnosticItemStatus.blocked,
      blockedByLabel: blockedByLabel,
      summary: summary ?? '等待 $blockedByLabel 就绪',
    );
  }

  DiagnosticItemState copyWith({
    DiagnosticItemStatus? status,
    String? summary,
  }) {
    return DiagnosticItemState(
      kind: kind,
      itemKey: itemKey,
      displayName: displayName,
      status: status ?? this.status,
      elapsedMs: elapsedMs,
      summary: summary ?? this.summary,
      cause: cause,
      fixHint: fixHint,
      fixTarget: fixTarget,
      blockedByLabel: blockedByLabel,
    );
  }
}
