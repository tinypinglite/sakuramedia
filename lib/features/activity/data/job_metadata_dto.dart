import 'package:sakuramedia/features/activity/data/task_run_dto.dart';

class JobMetadataDto {
  const JobMetadataDto({
    required this.taskKey,
    required this.logName,
    required this.cliName,
    required this.cliHelp,
    required this.cronSetting,
    required this.cronExpr,
    required this.manualTriggerAllowed,
    required this.lastTaskRun,
  });

  final String taskKey;
  final String logName;
  final String cliName;
  final String cliHelp;
  final String cronSetting;
  final String cronExpr;
  final bool manualTriggerAllowed;
  final TaskRunDto? lastTaskRun;

  factory JobMetadataDto.fromJson(Map<String, dynamic> json) {
    return JobMetadataDto(
      taskKey: json['task_key'] as String? ?? '',
      logName: json['log_name'] as String? ?? '',
      cliName: json['cli_name'] as String? ?? '',
      cliHelp: json['cli_help'] as String? ?? '',
      cronSetting: json['cron_setting'] as String? ?? '',
      cronExpr: json['cron_expr'] as String? ?? '',
      manualTriggerAllowed: json['manual_trigger_allowed'] as bool? ?? false,
      lastTaskRun: _taskRunFromJson(json['last_task_run']),
    );
  }

  static TaskRunDto? _taskRunFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return TaskRunDto.fromJson(value);
    }
    if (value is Map) {
      return TaskRunDto.fromJson(
        value.map(
          (dynamic key, dynamic data) => MapEntry(key.toString(), data),
        ),
      );
    }
    return null;
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
      taskRunId: _toInt(json['task_run_id']),
      taskKey: json['task_key'] as String? ?? '',
      state: json['state'] as String? ?? '',
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}
