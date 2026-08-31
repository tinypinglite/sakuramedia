import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_fix_target.dart';

/// 「两段式」诊断文案：哪坏了 / 怎么改。
///
/// **写文案的规矩**（面向自建 NAS 的普通用户，不是开发者）：
/// - 一句话说完，不加括号补丁，不解释内部机制。
/// - 只用用户看得见的名词：界面上的配置项名、qBittorrent / 115 / JavDB 这类产品名。
///   内部实现名（哨兵文件、trust_env、Torznab、collection、OSError…）一律不进文案。
/// - **不猜原因**：拿不准的归因（"最常见的原因是…"）不写，宁可只说"连不上"。
/// - 后端侧自称统一用「后端」。
/// - 不写"影响"：猜不准，且用户看到红点自然知道这块不能用了。
@immutable
class DiagnosticHint {
  const DiagnosticHint({
    required this.cause,
    required this.fixHint,
    this.fixTarget,
  });

  final String cause;
  final String fixHint;
  final DiagnosticFixTarget? fixTarget;
}
