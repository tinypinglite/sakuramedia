/// 单项诊断项当前的运行时状态。
///
/// - [disabled]: 对应功能未启用，不跑探测。
/// - [notTested]: 从未跑过（默认态、页面刚打开）。
/// - [probing]: 正在检测。
/// - [healthy]: 检测通过。
/// - [warning]: 业务上通过但带告警（例如硬链接不支持、索引器未在线校验）。
/// - [unhealthy]: 检测失败或抛异常。
/// - [blocked]: 前置依赖没通过（例如媒体库空 → 索引器无法测），不跑请求直接标灰。
enum DiagnosticItemStatus {
  disabled,
  notTested,
  probing,
  healthy,
  warning,
  unhealthy,
  blocked,
}

/// 一组状态的汇总规则，[DiagnosticCategoryState.aggregate] 和
/// [SystemDiagnosticsState.overallStatus] 共用同一份优先级：
/// 有任意 unhealthy → unhealthy；否则有 warning → warning；否则有 probing →
/// probing；否则全 healthy（不含 blocked）→ healthy；全 blocked（不含
/// healthy）→ blocked；healthy 与 blocked 混合（半通半挡）→ warning；
/// 全部为 disabled → disabled；其他（含 notTested、空列表）→ notTested。
DiagnosticItemStatus mergeDiagnosticStatuses(
  Iterable<DiagnosticItemStatus> statuses,
) {
  var hasDisabled = false;
  var hasOther = false;
  var hasWarning = false;
  var hasProbing = false;
  var hasHealthy = false;
  var hasBlocked = false;
  for (final status in statuses) {
    if (status != DiagnosticItemStatus.disabled) hasOther = true;
    switch (status) {
      case DiagnosticItemStatus.disabled:
        hasDisabled = true;
      case DiagnosticItemStatus.unhealthy:
        return DiagnosticItemStatus.unhealthy;
      case DiagnosticItemStatus.warning:
        hasWarning = true;
      case DiagnosticItemStatus.probing:
        hasProbing = true;
      case DiagnosticItemStatus.healthy:
        hasHealthy = true;
      case DiagnosticItemStatus.blocked:
        hasBlocked = true;
      case DiagnosticItemStatus.notTested:
        break;
    }
  }
  if (hasDisabled && !hasOther) return DiagnosticItemStatus.disabled;
  if (hasWarning) return DiagnosticItemStatus.warning;
  if (hasProbing) return DiagnosticItemStatus.probing;
  if (hasHealthy && !hasBlocked) return DiagnosticItemStatus.healthy;
  if (hasBlocked && !hasHealthy) return DiagnosticItemStatus.blocked;
  if (hasHealthy && hasBlocked) return DiagnosticItemStatus.warning;
  return DiagnosticItemStatus.notTested;
}
