import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';

/// `/system/task-runs/attention` 的单条重点任务。
///
/// 后端只下发「最新一次运行失败、或完成但带警告」的任务；旧后端没有该接口时
/// 由调用方把整段重点区隐藏，不阻断任务中心其它内容。
class TaskAttentionDto {
  const TaskAttentionDto({
    required this.taskKey,
    required this.taskName,
    required this.latestRun,
    required this.failedCount7d,
    required this.lastIssueAt,
  });

  final String taskKey;
  final String taskName;

  /// 该任务最新一次终态运行；缺失字段时为 null，由 UI 回退到任务名与计数。
  final TaskRunDto? latestRun;

  /// 近 7 天进入 failed 终态的次数；完成但带警告的告警不计入。
  final int failedCount7d;

  /// 最近一次出问题的时间。
  final DateTime? lastIssueAt;

  String get displayName {
    final name = taskName.trim();
    if (name.isNotEmpty) return name;
    final runName = latestRun?.taskName.trim() ?? '';
    return runName.isNotEmpty ? runName : taskKey;
  }

  factory TaskAttentionDto.fromJson(Map<String, dynamic> json) {
    final latestRunJson = asMapOrNull(json['latest_run']);
    return TaskAttentionDto(
      taskKey: json['task_key'] as String? ?? '',
      taskName: json['task_name'] as String? ?? '',
      latestRun: latestRunJson == null
          ? null
          : TaskRunDto.fromJson(latestRunJson),
      failedCount7d: asIntOrNull(json['failed_count_7d']) ?? 0,
      lastIssueAt: asDateTime(json['last_issue_at']),
    );
  }

  /// 值相等：轮询写入 state 前依赖它判断重点区是否实质变化。
  @override
  bool operator ==(Object other) {
    return other is TaskAttentionDto &&
        other.taskKey == taskKey &&
        other.taskName == taskName &&
        other.latestRun == latestRun &&
        other.failedCount7d == failedCount7d &&
        other.lastIssueAt == lastIssueAt;
  }

  @override
  int get hashCode =>
      Object.hash(taskKey, taskName, latestRun, failedCount7d, lastIssueAt);
}
