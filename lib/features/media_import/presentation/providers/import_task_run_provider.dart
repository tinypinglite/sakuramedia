import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_api_provider.dart';

part 'import_task_run_provider.g.dart';

/// 导入页「最近一次导入」状态卡的数据源。
///
/// 任务活跃期间每 3 秒拉一次单条任务运行；到达终态后流结束，页面不再轮询。
/// 离开页面时 provider autoDispose，流随之取消。
@riverpod
Stream<TaskRunDto> importTaskRun(Ref ref, int taskRunId) async* {
  final api = ref.read(activityApiProvider);
  while (true) {
    final run = await api.getTaskRun(taskRunId);
    yield run;
    if (!run.isActive) {
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
}
