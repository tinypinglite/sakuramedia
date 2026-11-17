import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';
import 'package:sakuramedia/features/activity/presentation/activity_job_sections.dart';
import 'package:sakuramedia/features/activity/presentation/activity_plugin_names.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';

void main() {
  test(
    'builds common tasks in curated order and excludes them from system',
    () {
      final sections = buildActivityJobSections(<JobMetadataDto>[
        _job('movie_heat_update'),
        _job('media_file_scan'),
        _job('actor_subscription_sync'),
        _job('subscribed_movie_auto_download'),
        _job('download_task_sync'),
      ]);

      expect(sections.map((section) => section.kind), <ActivityJobSectionKind>[
        ActivityJobSectionKind.common,
        ActivityJobSectionKind.system,
      ]);
      expect(sections[0].jobs.map((job) => job.taskKey), <String>[
        'actor_subscription_sync',
        'subscribed_movie_auto_download',
        'download_task_sync',
        'media_file_scan',
      ]);
      expect(sections[1].jobs.map((job) => job.taskKey), <String>[
        'movie_heat_update',
      ]);
    },
  );

  test('skips missing common tasks and keeps plugin first-seen order', () {
    final sections = buildActivityJobSections(<JobMetadataDto>[
      _job('system_a'),
      _job('plugin_b_job', pluginId: 'plugin_b'),
      _job('plugin_a_job_1', pluginId: 'plugin_a'),
      _job('plugin_b_other', pluginId: 'plugin_b'),
      _job('plugin_a_job_2', pluginId: 'plugin_a'),
    ]);

    expect(sections.map((section) => section.kind), <ActivityJobSectionKind>[
      ActivityJobSectionKind.system,
      ActivityJobSectionKind.plugin,
      ActivityJobSectionKind.plugin,
    ]);
    expect(sections[1].pluginId, 'plugin_b');
    expect(sections[1].jobs.map((job) => job.taskKey), <String>[
      'plugin_b_job',
      'plugin_b_other',
    ]);
    expect(sections[2].pluginId, 'plugin_a');
    expect(sections[2].jobs.map((job) => job.taskKey), <String>[
      'plugin_a_job_1',
      'plugin_a_job_2',
    ]);
  });

  test('plugin display names prefer localized names and fall back to id', () {
    final names = activityPluginDisplayNames(<PluginSummaryDto>[
      _plugin('plugin_a', '插件 A'),
      _plugin('plugin_b', '   '),
    ]);

    expect(activityPluginDisplayName('plugin_a', names), '插件 A');
    expect(activityPluginDisplayName('plugin_b', names), 'plugin_b');
    expect(activityPluginDisplayName('plugin_c', names), 'plugin_c');
  });

  test('hides the stats sync job when stats are disabled', () {
    final jobs = <JobMetadataDto>[
      _job(movieStatsSyncTaskKey),
      _job('download_task_sync'),
    ];

    expect(
      visibleActivityJobs(jobs, statsEnabled: false).map((job) => job.taskKey),
      <String>['download_task_sync'],
    );
    expect(
      visibleActivityJobs(jobs, statsEnabled: true).map((job) => job.taskKey),
      <String>[movieStatsSyncTaskKey, 'download_task_sync'],
    );
  });
}

JobMetadataDto _job(String taskKey, {String? pluginId}) {
  return JobMetadataDto(
    taskKey: taskKey,
    pluginId: pluginId,
    logName: taskKey,
    cliName: taskKey,
    cliHelp: taskKey,
    cronSetting: '',
    cronExpr: '',
    manualTriggerAllowed: true,
    paramsSchema: null,
    lastTaskRun: null,
  );
}

PluginSummaryDto _plugin(String id, String displayName) {
  return PluginSummaryDto(
    pluginId: id,
    displayName: displayName,
    version: '1.0.0',
    hostApiVersion: 12,
    enabled: true,
    loadStatus: 'ok',
  );
}
