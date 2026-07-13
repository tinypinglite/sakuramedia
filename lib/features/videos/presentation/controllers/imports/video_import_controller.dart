import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/activity/data/activity_api.dart';
import 'package:sakuramedia/features/activity/data/activity_event_stream_client.dart';
import 'package:sakuramedia/features/activity/data/activity_stream_event.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/features/media_import/data/media_import_source.dart';
import 'package:sakuramedia/features/media_import/presentation/import_jobs_view_controller.dart';
import 'package:sakuramedia/features/videos/data/dto/video_import_job_dto.dart';
import 'package:sakuramedia/features/videos/data/api/video_imports_api.dart';

/// 视频（PornBox）导入后台作业的 task_run task_key。
const String kVideoImportTaskKey = 'video_directory_import';

/// 视频导入页状态：作业分页列表 + 失败文件详情懒加载 + task_run SSE 实时进度。
///
/// 结构与 JAV `MediaImportController` 一致，仅数据源换为 `/video-imports`。
class VideoImportController extends ChangeNotifier
    implements ImportJobsViewController {
  VideoImportController({
    required VideoImportsApi videoImportsApi,
    required ActivityApi activityApi,
    this.pageSize = 20,
  }) : _videoImportsApi = videoImportsApi,
       _activityApi = activityApi;

  final VideoImportsApi _videoImportsApi;
  final ActivityApi _activityApi;
  final int pageSize;

  // 作业列表分页状态。
  List<VideoImportJobListItemDto> _jobs = const <VideoImportJobListItemDto>[];
  int _nextPage = 1;
  bool _hasMore = false;
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  bool _isReconciling = false;
  String? _initialError;
  String? _loadMoreError;

  // 作业详情（失败文件）懒加载缓存。
  final Map<int, VideoImportJobDto> _details = <int, VideoImportJobDto>{};
  final Set<int> _detailLoading = <int>{};
  final Map<int, String> _detailErrors = <int, String>{};

  // task_run 实时进度表（仅保留视频导入任务），按 task_run id 索引。
  final Map<int, TaskRunDto> _taskRunsById = <int, TaskRunDto>{};

  // SSE 订阅。
  StreamSubscription<ActivityStreamEvent>? _eventSubscription;
  Timer? _reconnectTimer;
  int _lastEventId = 0;
  bool _streamSeeded = false;
  bool _streamUnsupported = false;
  bool _disposed = false;

  static const List<Duration> _reconnectDelays = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];
  int _reconnectAttempt = 0;

  @override
  List<VideoImportJobListItemDto> get jobs => _jobs;
  @override
  bool get isInitialLoading => _isInitialLoading;
  @override
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  @override
  String? get initialError => _initialError;
  @override
  String? get loadMoreError => _loadMoreError;
  bool get isEmpty => !_isInitialLoading && _initialError == null && _jobs.isEmpty;

  /// 返回某作业关联的实时 task_run（若有）。
  @override
  TaskRunDto? taskRunFor(int? taskRunId) {
    if (taskRunId == null) {
      return null;
    }
    return _taskRunsById[taskRunId];
  }

  @override
  VideoImportJobDto? detailFor(int jobId) => _details[jobId];
  @override
  bool isDetailLoading(int jobId) => _detailLoading.contains(jobId);
  @override
  String? detailError(int jobId) => _detailErrors[jobId];

  Future<void> initialize() async {
    await loadFirstPage();
    // 进度流是增量增强，失败不影响列表展示，后台静默连接。
    unawaited(_ensureStreamConnected());
  }

  @override
  Future<void> loadFirstPage() async {
    _isInitialLoading = true;
    _initialError = null;
    _notify();
    try {
      final response = await _videoImportsApi.listVideoImportJobs(
        page: 1,
        pageSize: pageSize,
      );
      _jobs = response.items;
      _nextPage = 2;
      _hasMore = _jobs.length < response.total;
      _loadMoreError = null;
    } catch (error) {
      _initialError = apiErrorMessage(error, fallback: '加载导入作业失败，请稍后重试。');
    } finally {
      _isInitialLoading = false;
      _notify();
    }
  }

  /// 用户主动刷新：重置分页、只保留第一页（丢弃已滚动加载的后续页）。
  @override
  Future<void> refresh() async {
    if (_isRefreshing) {
      return;
    }
    _isRefreshing = true;
    try {
      final response = await _videoImportsApi.listVideoImportJobs(
        page: 1,
        pageSize: pageSize,
      );
      _jobs = response.items;
      _nextPage = 2;
      _hasMore = _jobs.length < response.total;
      _initialError = null;
      _loadMoreError = null;
      _notify();
    } catch (_) {
      // 静默：刷新失败保留原列表。
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _isInitialLoading) {
      return;
    }
    _isLoadingMore = true;
    _loadMoreError = null;
    _notify();
    try {
      final response = await _videoImportsApi.listVideoImportJobs(
        page: _nextPage,
        pageSize: pageSize,
      );
      // 去重：实时合并可能让分页边界出现已加载项，避免重复插入。
      final existingIds = _jobs.map((job) => job.id).toSet();
      _jobs = <VideoImportJobListItemDto>[
        ..._jobs,
        ...response.items.where((job) => !existingIds.contains(job.id)),
      ];
      _nextPage = response.page + 1;
      _hasMore = _jobs.length < response.total;
    } catch (error) {
      _loadMoreError = apiErrorMessage(error, fallback: '加载更多失败，请重试。');
    } finally {
      _isLoadingMore = false;
      _notify();
    }
  }

  /// 懒加载作业详情（失败文件）。[force] 为 true 时忽略缓存重新拉取。
  @override
  Future<void> ensureDetail(int jobId, {bool force = false}) async {
    if (!force && _details.containsKey(jobId)) {
      return;
    }
    if (_detailLoading.contains(jobId)) {
      return;
    }
    _detailLoading.add(jobId);
    _detailErrors.remove(jobId);
    _notify();
    try {
      final detail = await _videoImportsApi.getVideoImportJob(jobId);
      _details[jobId] = detail;
      _replaceJob(detail);
    } catch (error) {
      _detailErrors[jobId] = apiErrorMessage(error, fallback: '加载失败文件失败，请重试。');
    } finally {
      _detailLoading.remove(jobId);
      _notify();
    }
  }

  /// 触发视频导入。成功返回 `null`，失败返回中文错误信息。[source] 兼容本地路径与 115 CID。
  Future<String?> triggerImport({
    required int libraryId,
    required MediaImportSource source,
    required TransferMode transferMode,
    int? collectionId,
  }) async {
    try {
      await _videoImportsApi.createVideoImport(
        libraryId: libraryId,
        source: source,
        transferMode: transferMode,
        collectionId: collectionId,
      );
      await refresh();
      return null;
    } catch (error) {
      return apiErrorMessage(error, fallback: '触发导入失败，请稍后重试。');
    }
  }

  /// 重导失败文件。[files] 为空表示重导全部可重导失败文件。成功返回 `null`。
  @override
  Future<String?> retryFailedFiles(int jobId, {List<String>? files}) async {
    try {
      await _videoImportsApi.retryFailedFiles(jobId, files: files);
      await refresh();
      return null;
    } catch (error) {
      return apiErrorMessage(error, fallback: '重导失败文件失败，请稍后重试。');
    }
  }

  void _replaceJob(VideoImportJobListItemDto job) {
    final index = _jobs.indexWhere((item) => item.id == job.id);
    if (index < 0) {
      return;
    }
    final next = List<VideoImportJobListItemDto>.from(_jobs);
    next[index] = job;
    _jobs = next;
  }

  // ---- SSE 实时进度 ----

  Future<void> _ensureStreamConnected() async {
    if (_disposed || _streamUnsupported || _eventSubscription != null) {
      return;
    }
    if (!_streamSeeded) {
      try {
        final bootstrap = await _activityApi.getBootstrap();
        _lastEventId = bootstrap.latestEventId;
        for (final run in bootstrap.activeTaskRuns) {
          if (run.taskKey == kVideoImportTaskKey) {
            _taskRunsById[run.id] = run;
          }
        }
        _streamSeeded = true;
        if (_taskRunsById.isNotEmpty) {
          _notify();
        }
      } catch (_) {
        // 拿不到起始事件 id 就不订阅（避免 after_event_id=0 回放全量历史），稍后重试。
        _scheduleReconnect();
        return;
      }
    }
    if (_disposed) {
      return;
    }
    final stream = _activityApi.streamEvents(afterEventId: _lastEventId);
    _eventSubscription = stream.listen(
      _handleStreamEvent,
      onError: _onStreamError,
      onDone: _onStreamBroken,
      cancelOnError: false,
    );
    _reconnectAttempt = 0;
  }

  void _handleStreamEvent(ActivityStreamEvent event) {
    if (event.id != null && event.id! > _lastEventId) {
      _lastEventId = event.id!;
    }
    final run = event.taskRun;
    if (run == null ||
        !(event.isTaskRunCreated || event.isTaskRunUpdated) ||
        run.taskKey != kVideoImportTaskKey) {
      return;
    }

    _taskRunsById[run.id] = run;

    final job = _jobForTaskRun(run.id);
    if (job == null) {
      // 仅「新建」事件才去拉第一页让新作业浮现；运行中作业若在后续页里，
      // 其 update 事件不应反复触发刷新（否则永远找不到、形成刷新风暴）。
      if (event.isTaskRunCreated) {
        unawaited(_reconcileFirstPage());
      }
    } else if (run.isFinished) {
      // 终态：刷新该作业计数与失败文件。
      unawaited(_refreshJobAfterFinish(job.id));
    }
    _notify();
  }

  /// 实时合并第一页：覆盖已有项、并入新作业，保留已滚动加载的后续页。
  Future<void> _reconcileFirstPage() async {
    if (_isReconciling) {
      return;
    }
    _isReconciling = true;
    try {
      final response = await _videoImportsApi.listVideoImportJobs(
        page: 1,
        pageSize: pageSize,
      );
      if (_disposed) {
        return;
      }
      final fresh = <int, VideoImportJobListItemDto>{
        for (final job in response.items) job.id: job,
      };
      // 第一页用新数据覆盖；其余保留旧项。列表按 id 倒序，新作业天然在最前。
      final merged = <VideoImportJobListItemDto>[
        ...response.items,
        for (final job in _jobs)
          if (!fresh.containsKey(job.id)) job,
      ]..sort((left, right) => right.id.compareTo(left.id));
      _jobs = merged;
      // 已加载项数可能因新增而变化，据此重算分页游标与是否还有更多。
      _nextPage = (merged.length / pageSize).ceil() + 1;
      _hasMore = merged.length < response.total;
      _notify();
    } catch (_) {
      // 静默：实时合并失败不影响既有列表与进度展示。
    } finally {
      _isReconciling = false;
    }
  }

  VideoImportJobListItemDto? _jobForTaskRun(int taskRunId) {
    for (final job in _jobs) {
      if (job.taskRunId == taskRunId) {
        return job;
      }
    }
    return null;
  }

  Future<void> _refreshJobAfterFinish(int jobId) async {
    try {
      final detail = await _videoImportsApi.getVideoImportJob(jobId);
      if (_disposed) {
        return;
      }
      // 仅当详情已被展开缓存过时才更新缓存，避免给未展开的作业平白填充。
      if (_details.containsKey(jobId)) {
        _details[jobId] = detail;
      }
      _replaceJob(detail);
      _notify();
    } catch (_) {
      // 静默：终态刷新失败不影响实时进度展示。
    }
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    // 平台不支持 SSE（如部分浏览器）：实时进度只是增强，直接放弃订阅，不再重连。
    if (error is ActivityEventStreamUnsupportedException) {
      _streamUnsupported = true;
      _eventSubscription?.cancel();
      _eventSubscription = null;
      return;
    }
    _onStreamBroken();
  }

  void _onStreamBroken() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectTimer != null) {
      return;
    }
    final delay = _reconnectDelays[_reconnectAttempt.clamp(
      0,
      _reconnectDelays.length - 1,
    )];
    _reconnectAttempt += 1;
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      unawaited(_ensureStreamConnected());
    });
  }

  void _notify() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _eventSubscription?.cancel();
    super.dispose();
  }
}
