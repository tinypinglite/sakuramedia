import 'package:sakuramedia/core/json/json_parse.dart';

/// `POST /imports` 与 `POST /subtitle-imports` 的异步受理结果。
class ImportAcceptedResponseDto {
  const ImportAcceptedResponseDto({
    required this.taskRunId,
    required this.taskKey,
    required this.state,
  });

  final int taskRunId;
  final String taskKey;
  final String state;

  factory ImportAcceptedResponseDto.fromJson(Map<String, dynamic> json) {
    return ImportAcceptedResponseDto(
      taskRunId: asInt(json['task_run_id']),
      taskKey: json['task_key'] as String? ?? '',
      state: json['state'] as String? ?? '',
    );
  }
}
