import 'package:sakuramedia/core/json/json_parse.dart';

class DownloadTaskActionResultDto {
  const DownloadTaskActionResultDto({
    required this.taskId,
    required this.action,
    required this.status,
  });

  final int taskId;
  final String action;
  final String status;

  factory DownloadTaskActionResultDto.fromJson(Map<String, dynamic> json) {
    return DownloadTaskActionResultDto(
      taskId: asInt(json['task_id']),
      action: json['action'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}
