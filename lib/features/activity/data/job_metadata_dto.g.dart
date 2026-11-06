// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_metadata_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JobMetadataDto _$JobMetadataDtoFromJson(Map<String, dynamic> json) =>
    JobMetadataDto(
      taskKey: const StringJsonConverter().fromJson(json['task_key']),
      pluginId: const NullableStringJsonConverter().fromJson(json['plugin_id']),
      logName: const StringJsonConverter().fromJson(json['log_name']),
      cliName: const StringJsonConverter().fromJson(json['cli_name']),
      cliHelp: const StringJsonConverter().fromJson(json['cli_help']),
      cronSetting: const StringJsonConverter().fromJson(json['cron_setting']),
      cronExpr: const StringJsonConverter().fromJson(json['cron_expr']),
      manualTriggerAllowed: const BoolJsonConverter().fromJson(
        json['manual_trigger_allowed'],
      ),
      disabledReason: const NullableStringJsonConverter().fromJson(
        json['disabled_reason'],
      ),
      paramsSchema: asMapOrNull(json['params_schema']),
      lastTaskRun: _taskRunFromJson(json['last_task_run']),
    );

ManualJobTriggerResponseDto _$ManualJobTriggerResponseDtoFromJson(
  Map<String, dynamic> json,
) => ManualJobTriggerResponseDto(
  taskRunId: const IntJsonConverter().fromJson(json['task_run_id']),
  taskKey: const StringJsonConverter().fromJson(json['task_key']),
  state: const StringJsonConverter().fromJson(json['state']),
);
