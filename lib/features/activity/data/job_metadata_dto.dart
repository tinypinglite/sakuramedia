import 'package:json_annotation/json_annotation.dart';
import 'package:sakuramedia/core/json/dto_json_codec.dart';
import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';

part 'job_metadata_dto.g.dart';

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
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
  @JsonKey(fromJson: asMapOrNull)
  final Map<String, dynamic>? paramsSchema;

  @JsonKey(fromJson: _taskRunFromJson)
  final TaskRunDto? lastTaskRun;

  /// 配置了定时表达式即为自动任务（会被调度器按计划触发）。
  bool get isScheduled => cronExpr.trim().isNotEmpty;

  /// 最近一次运行失败，或完成带警告。
  bool get needsAttention => lastTaskRun?.needsAttention ?? false;

  factory JobMetadataDto.fromJson(Map<String, dynamic> json) =>
      _$JobMetadataDtoFromJson(json);
}

TaskRunDto? _taskRunFromJson(Object? value) =>
    asObjectOrNull(value, TaskRunDto.fromJson);

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class ManualJobTriggerResponseDto {
  const ManualJobTriggerResponseDto({
    required this.taskRunId,
    required this.taskKey,
    required this.state,
  });

  final int taskRunId;
  final String taskKey;
  final String state;

  factory ManualJobTriggerResponseDto.fromJson(Map<String, dynamic> json) =>
      _$ManualJobTriggerResponseDtoFromJson(json);
}
