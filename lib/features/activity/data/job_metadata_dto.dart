import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';

class JobMetadataDto {
  const JobMetadataDto({
    required this.taskKey,
    this.pluginId,
    required this.logName,
    required this.cliName,
    required this.cliHelp,
    required this.cronSetting,
    required this.cronExpr,
    required this.manualTriggerAllowed,
    this.disabledReason,
    required this.paramsSchema,
    required this.lastTaskRun,
  });

  final String taskKey;
  final String? pluginId;
  final String logName;
  final String cliName;
  final String cliHelp;
  final String cronSetting;
  final String cronExpr;
  final bool manualTriggerAllowed;
  final String? disabledReason;
  final Map<String, dynamic>? paramsSchema;
  final TaskRunDto? lastTaskRun;

  /// 配置了定时表达式即为自动任务（会被调度器按计划触发）。
  bool get isScheduled => cronExpr.trim().isNotEmpty;

  /// 最近一次运行失败，或完成带警告。
  bool get needsAttention => lastTaskRun?.needsAttention ?? false;

  factory JobMetadataDto.fromJson(Map<String, dynamic> json) {
    final lastTaskRunJson = asMapOrNull(json['last_task_run']);
    return JobMetadataDto(
      taskKey: json['task_key'] as String? ?? '',
      pluginId: json['plugin_id'] as String?,
      logName: json['log_name'] as String? ?? '',
      cliName: json['cli_name'] as String? ?? '',
      cliHelp: json['cli_help'] as String? ?? '',
      cronSetting: json['cron_setting'] as String? ?? '',
      cronExpr: json['cron_expr'] as String? ?? '',
      manualTriggerAllowed: json['manual_trigger_allowed'] as bool? ?? false,
      disabledReason: json['disabled_reason'] as String?,
      paramsSchema: asMapOrNull(json['params_schema']),
      lastTaskRun: lastTaskRunJson == null
          ? null
          : TaskRunDto.fromJson(lastTaskRunJson),
    );
  }
}

class ManualJobTriggerResponseDto {
  const ManualJobTriggerResponseDto({
    required this.taskRunId,
    required this.taskKey,
    required this.state,
  });

  final int taskRunId;
  final String taskKey;
  final String state;

  factory ManualJobTriggerResponseDto.fromJson(Map<String, dynamic> json) {
    return ManualJobTriggerResponseDto(
      taskRunId: asInt(json['task_run_id']),
      taskKey: json['task_key'] as String? ?? '',
      state: json['state'] as String? ?? '',
    );
  }
}
