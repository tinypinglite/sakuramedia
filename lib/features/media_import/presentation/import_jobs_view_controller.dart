import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/features/media_import/data/import_job_dto.dart';

/// 导入作业列表页所需的统一控制器接口。
///
/// JAV `MediaImportController` 与 PornBox `VideoImportController` 各自实现本接口，
/// 让媒体导入页的标签内容用同一套渲染逻辑驱动两类导入作业。
/// 失败源文件的删除/重命名是 JAV 专属能力，不在本接口内
/// （见 `MediaImportController.deleteFailedFile` / `renameFailedFile`）。
abstract class ImportJobsViewController implements Listenable {
  List<ImportJobCardData> get jobs;
  bool get isInitialLoading;
  bool get isLoadingMore;
  String? get initialError;
  String? get loadMoreError;

  TaskRunDto? taskRunFor(int? taskRunId);
  ImportJobCardDetailData? detailFor(int jobId);
  bool isDetailLoading(int jobId);
  String? detailError(int jobId);

  Future<void> loadFirstPage();
  Future<void> refresh();
  Future<void> loadMore();
  Future<void> ensureDetail(int jobId, {bool force});
  Future<String?> retryFailedFiles(int jobId, {List<String>? files});
}
