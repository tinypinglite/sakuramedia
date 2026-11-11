import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';

/// 概览固定展示的常用任务；顺序即卡片顺序。
const List<String> activityCommonJobKeys = <String>[
  'actor_subscription_sync',
  'subscribed_movie_auto_download',
  'download_task_sync',
  'download_task_auto_import',
  'media_thumbnail_generation',
  'image_search_index',
  'media_file_scan',
];

enum ActivityJobSectionKind { common, system, plugin }

@immutable
class ActivityJobSection {
  ActivityJobSection({
    required this.kind,
    required List<JobMetadataDto> jobs,
    this.pluginId,
  }) : jobs = List<JobMetadataDto>.unmodifiable(jobs);

  final ActivityJobSectionKind kind;
  final String? pluginId;
  final List<JobMetadataDto> jobs;
}

/// 常用任务 → 系统任务 → 各插件任务。
///
/// 常用项只从系统任务里取；各分段内部保持接口顺序，插件分段按首次出现顺序。
List<ActivityJobSection> buildActivityJobSections(List<JobMetadataDto> jobs) {
  final systemJobs = jobs
      .where((job) => (job.pluginId ?? '').trim().isEmpty)
      .toList(growable: false);
  final systemJobsByKey = <String, JobMetadataDto>{
    for (final job in systemJobs) job.taskKey: job,
  };
  final commonJobs = <JobMetadataDto>[
    for (final key in activityCommonJobKeys)
      if (systemJobsByKey[key] case final JobMetadataDto job) job,
  ];
  final commonKeys = {for (final job in commonJobs) job.taskKey};
  final remainingSystemJobs = systemJobs
      .where((job) => !commonKeys.contains(job.taskKey))
      .toList(growable: false);
  final pluginJobs = <String, List<JobMetadataDto>>{};
  for (final job in jobs) {
    final pluginId = (job.pluginId ?? '').trim();
    if (pluginId.isEmpty) continue;
    pluginJobs.putIfAbsent(pluginId, () => <JobMetadataDto>[]).add(job);
  }

  return <ActivityJobSection>[
    if (commonJobs.isNotEmpty)
      ActivityJobSection(kind: ActivityJobSectionKind.common, jobs: commonJobs),
    if (remainingSystemJobs.isNotEmpty)
      ActivityJobSection(
        kind: ActivityJobSectionKind.system,
        jobs: remainingSystemJobs,
      ),
    for (final entry in pluginJobs.entries)
      ActivityJobSection(
        kind: ActivityJobSectionKind.plugin,
        pluginId: entry.key,
        jobs: entry.value,
      ),
  ];
}
