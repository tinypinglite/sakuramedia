import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_api.dart';
import 'package:sakuramedia/features/activity/data/media_thumbnail_reset_result_dto.dart';
import 'package:sakuramedia/features/activity/data/resource_task_definition_dto.dart';
import 'package:sakuramedia/features/activity/data/resource_task_record_dto.dart';
import 'package:sakuramedia/features/activity/presentation/resource_task_filter_state.dart';

/// 单个 task_key 下的分页状态缓存。
class _RecordsBucket {
  _RecordsBucket();

  List<ResourceTaskRecordDto> records = const <ResourceTaskRecordDto>[];
  int nextPage = 1;
  bool hasMore = true;
  bool hasLoadedOnce = false;
  bool isLoading = false;
  bool isLoadingMore = false;
  String? loadErrorMessage;
  String? loadMoreErrorMessage;
  int loadRequestId = 0;
  ResourceTaskRecordFilterState filter = ResourceTaskRecordFilterState.initial;
}

class ResourceTaskCenterController extends ChangeNotifier {
  ResourceTaskCenterController({required ActivityApi activityApi})
    : _activityApi = activityApi;

  static const int _pageSize = 20;

  /// 后端仅 `media_thumbnail_generation` 有批量 reset 端点；同时后端接口的
  /// task_key 也是硬编码。前端选择模式的可用性由该常量判定。
  static const String kMediaThumbnailTaskKey = 'media_thumbnail_generation';

  /// 后端 reset 端点 `resource_ids` 的 `max_length`。全选/单选都在此上限内截断。
  static const int maxBatchResetCount = 200;

  final ActivityApi _activityApi;

  bool _initialized = false;
  bool _isInitialLoading = false;
  bool _isRefreshingDefinitions = false;
  String? _initialErrorMessage;
  String? _definitionsRefreshErrorMessage;
  List<ResourceTaskDefinitionDto> _definitions =
      const <ResourceTaskDefinitionDto>[];
  String? _activeTaskKey;
  final Map<String, _RecordsBucket> _buckets = <String, _RecordsBucket>{};
  ResourceTaskRecordDto? _selectedRecord;
  bool _disposed = false;

  bool _selectionMode = false;
  final Set<int> _selectedResourceIds = <int>{};
  bool _isResetting = false;

  bool get initialized => _initialized;
  bool get isInitialLoading => _isInitialLoading;
  bool get isRefreshingDefinitions => _isRefreshingDefinitions;
  String? get initialErrorMessage => _initialErrorMessage;
  String? get definitionsRefreshErrorMessage => _definitionsRefreshErrorMessage;
  UnmodifiableListView<ResourceTaskDefinitionDto> get definitions =>
      UnmodifiableListView<ResourceTaskDefinitionDto>(_definitions);
  String? get activeTaskKey => _activeTaskKey;
  ResourceTaskDefinitionDto? get activeDefinition {
    final key = _activeTaskKey;
    if (key == null) {
      return null;
    }
    for (final definition in _definitions) {
      if (definition.taskKey == key) {
        return definition;
      }
    }
    return null;
  }

  ResourceTaskRecordFilterState get filter =>
      _bucketFor(_activeTaskKey)?.filter ??
      ResourceTaskRecordFilterState.initial;

  UnmodifiableListView<ResourceTaskRecordDto> get activeRecords {
    final bucket = _bucketFor(_activeTaskKey);
    return UnmodifiableListView<ResourceTaskRecordDto>(
      bucket?.records ?? const <ResourceTaskRecordDto>[],
    );
  }

  bool get isLoadingRecords => _bucketFor(_activeTaskKey)?.isLoading ?? false;
  bool get isLoadingMoreRecords =>
      _bucketFor(_activeTaskKey)?.isLoadingMore ?? false;
  bool get hasMoreRecords => _bucketFor(_activeTaskKey)?.hasMore ?? false;
  bool get hasLoadedActiveRecords =>
      _bucketFor(_activeTaskKey)?.hasLoadedOnce ?? false;
  String? get recordsLoadErrorMessage =>
      _bucketFor(_activeTaskKey)?.loadErrorMessage;
  String? get recordsLoadMoreErrorMessage =>
      _bucketFor(_activeTaskKey)?.loadMoreErrorMessage;

  ResourceTaskRecordDto? get selectedRecord => _selectedRecord;
  bool get isDetailOpen => _selectedRecord != null;

  bool get selectionMode => _selectionMode;
  int get selectedCount => _selectedResourceIds.length;
  bool get hasSelection => _selectedResourceIds.isNotEmpty;
  bool get isResetting => _isResetting;

  /// 是否当前 tab 支持批量重置(仅媒体缩略图生成)。
  bool get supportsBatchReset => _activeTaskKey == kMediaThumbnailTaskKey;

  bool isRecordSelected(int resourceId) =>
      _selectedResourceIds.contains(resourceId);

  /// 当前 bucket 里可批量重置的记录数(用于「全选」按钮的禁用与"可选分子")。
  ///
  /// 与 [ResourceTaskRecordDto.canBatchReset] 对齐:失效或已删除媒体不计入,
  /// 否则「全选」会把注定被后端跳过的 ID 一起提交。
  int get visibleFailedCount {
    final bucket = _bucketFor(_activeTaskKey);
    if (bucket == null) {
      return 0;
    }
    return bucket.records.where((record) => record.canBatchReset).length;
  }

  /// 当前 bucket 里所有 failed 记录数(含媒体不可用的不可选项),用作「全选」
  /// 按钮的分母,让用户看到"因为媒体不可用而少选的差值",而不是悄悄跳过。
  int get visibleFailedTotalCount {
    final bucket = _bucketFor(_activeTaskKey);
    if (bucket == null) {
      return 0;
    }
    return bucket.records.where((record) => record.isFailed).length;
  }

  /// 当前可见可重置记录是否已被全部选中(超过 200 时,前 200 全选即视为全选)。
  bool get isAllVisibleFailedSelected {
    final visibleFailedIds = _visibleFailedResourceIds();
    if (visibleFailedIds.isEmpty) {
      return false;
    }
    return visibleFailedIds.every(_selectedResourceIds.contains);
  }

  Future<void> initialize() async {
    if (_initialized || _isInitialLoading) {
      return;
    }
    _isInitialLoading = true;
    _initialErrorMessage = null;
    _notifySafely();

    try {
      final definitions = await _activityApi.getResourceTaskDefinitions();
      _definitions = definitions;
      _initialized = true;
      _isInitialLoading = false;

      if (definitions.isNotEmpty) {
        final firstKey = definitions.first.taskKey;
        _activeTaskKey = firstKey;
        _ensureBucket(firstKey);
        _notifySafely();
        await _loadFirstPage(firstKey);
      } else {
        _notifySafely();
      }
    } catch (error) {
      _isInitialLoading = false;
      _initialErrorMessage = apiErrorMessage(
        error,
        fallback: '资源任务定义加载失败，请稍后重试',
      );
      _notifySafely();
    }
  }

  Future<void> retryInitialize() async {
    _initialized = false;
    await initialize();
  }

  Future<void> refreshDefinitions() async {
    if (_isRefreshingDefinitions) {
      return;
    }
    _isRefreshingDefinitions = true;
    _definitionsRefreshErrorMessage = null;
    _notifySafely();

    try {
      final definitions = await _activityApi.getResourceTaskDefinitions();
      _definitions = definitions;
      _isRefreshingDefinitions = false;

      // 如果当前选中的 task_key 已经不存在，回落到第一个。
      if (_activeTaskKey != null &&
          definitions.every((item) => item.taskKey != _activeTaskKey)) {
        _activeTaskKey = definitions.isEmpty ? null : definitions.first.taskKey;
      }
      // 如果从未选过任务，但现在有任务了，初始化第一个。
      if (_activeTaskKey == null && definitions.isNotEmpty) {
        _activeTaskKey = definitions.first.taskKey;
      }
      _notifySafely();

      final key = _activeTaskKey;
      if (key != null && !_ensureBucket(key).hasLoadedOnce) {
        await _loadFirstPage(key);
      }
    } catch (error) {
      _isRefreshingDefinitions = false;
      _definitionsRefreshErrorMessage = apiErrorMessage(
        error,
        fallback: '任务定义刷新失败，请稍后重试',
      );
      _notifySafely();
    }
  }

  Future<void> selectTaskKey(String taskKey) async {
    if (_activeTaskKey == taskKey) {
      return;
    }
    _activeTaskKey = taskKey;
    final bucket = _ensureBucket(taskKey);
    _resetSelectionState();
    _notifySafely();

    if (!bucket.hasLoadedOnce && !bucket.isLoading) {
      await _loadFirstPage(taskKey);
    }
  }

  Future<void> applyFilter(ResourceTaskRecordFilterState next) async {
    final key = _activeTaskKey;
    if (key == null) {
      return;
    }
    final bucket = _ensureBucket(key);
    if (bucket.filter == next) {
      return;
    }
    bucket.filter = next;
    _resetSelectionState();
    _notifySafely();
    await _loadFirstPage(key);
  }

  void enterSelectionMode() {
    if (!supportsBatchReset || _selectionMode) {
      return;
    }
    _selectionMode = true;
    _notifySafely();
  }

  void exitSelectionMode() {
    if (!_selectionMode && _selectedResourceIds.isEmpty) {
      return;
    }
    _selectionMode = false;
    _selectedResourceIds.clear();
    _notifySafely();
  }

  /// 切换单条选中。达到 [maxBatchResetCount] 上限时新增被拒,返回 `false`;
  /// 其余成功返回 `true`。UI 可据此提示「最多可选 N 项」。
  bool toggleRecordSelection(int resourceId) {
    if (_selectedResourceIds.remove(resourceId)) {
      _notifySafely();
      return true;
    }
    if (_selectedResourceIds.length >= maxBatchResetCount) {
      return false;
    }
    _selectedResourceIds.add(resourceId);
    _notifySafely();
    return true;
  }

  /// 全选当前可见可重置记录(截取前 200);已全选时清空。
  void toggleSelectAllVisibleFailed() {
    final visibleFailedIds = _visibleFailedResourceIds();
    if (visibleFailedIds.isEmpty) {
      return;
    }
    final allSelected = visibleFailedIds.every(_selectedResourceIds.contains);
    if (allSelected) {
      _selectedResourceIds.removeAll(visibleFailedIds);
    } else {
      _selectedResourceIds.addAll(visibleFailedIds);
    }
    _notifySafely();
  }

  /// 触发批量 reset,返回后端结果供调用方组织提示文案。
  ///
  /// 后端是**部分成功**语义:合格记录被重置并回报在 `resource_ids` 里,不合格的
  /// 只出现在 `skipped` 中,全部不合格时也返回 200(`reset_count == 0`)。因此这里
  /// 只移除 `resource_ids` 里真正被重置的记录——**不能**在 `resource_ids` 为空时
  /// 回落成"整批已重置",那会把没重置的记录也从列表里抹掉。
  ///
  /// 被跳过的项保留选中态并停在选择模式,方便用户看到是哪几条没成功;全部成功
  /// 才退出选择模式。传输/协议层失败仍保持已选并 `rethrow`,让调用方(通常是
  /// `showAppConfirmDialog(onConfirm:)`)兜底 toast + 保留 dialog。
  ///
  /// 未发起请求(非媒体 tab / 无选中 / 正在重置)时返回 `null`。
  Future<MediaThumbnailResetResultDto?> resetSelectedFailed() async {
    if (_isResetting ||
        _activeTaskKey != kMediaThumbnailTaskKey ||
        _selectedResourceIds.isEmpty) {
      return null;
    }
    final ids = _selectedResourceIds.toList(growable: false);
    _isResetting = true;
    _notifySafely();
    try {
      final result = await _activityApi.resetFailedMediaThumbnailStates(
        resourceIds: ids,
      );
      if (_disposed) {
        return result;
      }
      final resetIds = result.resourceIds.toSet();
      _applySuccessfulReset(resetIds, result.resetCount);
      _isResetting = false;
      // 被跳过的仍留在列表里,保持选中让用户能定位;其余从选中集合里剔除。
      final keepSelected = _selectedResourceIds
          .where((id) => !resetIds.contains(id))
          .toSet();
      _selectedResourceIds
        ..clear()
        ..addAll(keepSelected);
      _selectionMode = _selectedResourceIds.isNotEmpty;
      _notifySafely();
      return result;
    } catch (error) {
      if (_disposed) {
        return null;
      }
      _isResetting = false;
      _notifySafely();
      rethrow;
    }
  }

  void _resetSelectionState() {
    _selectionMode = false;
    _selectedResourceIds.clear();
  }

  List<int> _visibleFailedResourceIds() {
    final bucket = _bucketFor(_activeTaskKey);
    if (bucket == null) {
      return const <int>[];
    }
    final ids = <int>[];
    for (final record in bucket.records) {
      if (!record.canBatchReset) {
        continue;
      }
      ids.add(record.resourceId);
      if (ids.length >= maxBatchResetCount) {
        break;
      }
    }
    return ids;
  }

  void _applySuccessfulReset(Set<int> resetIds, int resetCount) {
    final bucket = _bucketFor(kMediaThumbnailTaskKey);
    if (bucket != null && resetIds.isNotEmpty) {
      final remaining = bucket.records
          .where((record) => !resetIds.contains(record.resourceId))
          .toList(growable: false);
      bucket.records = List<ResourceTaskRecordDto>.unmodifiable(remaining);
    }
    if (resetCount <= 0) {
      return;
    }
    _definitions = _definitions
        .map((definition) {
          if (definition.taskKey != kMediaThumbnailTaskKey) {
            return definition;
          }
          final counts = definition.stateCounts;
          final delta = resetCount > counts.failed ? counts.failed : resetCount;
          if (delta <= 0) {
            return definition;
          }
          return definition.copyWith(
            stateCounts: counts.copyWith(
              failed: counts.failed - delta,
              pending: counts.pending + delta,
            ),
          );
        })
        .toList(growable: false);
  }

  Future<void> refreshRecords() async {
    final key = _activeTaskKey;
    if (key == null) {
      return;
    }
    await _loadFirstPage(key);
  }

  Future<void> loadMoreRecords() async {
    final key = _activeTaskKey;
    if (key == null) {
      return;
    }
    final bucket = _ensureBucket(key);
    if (!bucket.hasMore ||
        bucket.isLoading ||
        bucket.isLoadingMore ||
        !bucket.hasLoadedOnce) {
      return;
    }

    final requestId = ++bucket.loadRequestId;
    _startLoadMore(bucket);
    _notifySafely();

    try {
      final response = await _fetchRecordsPage(
        key,
        page: bucket.nextPage,
        bucket: bucket,
      );

      if (_isStaleRequest(bucket, requestId)) {
        return;
      }

      _applyLoadMoreSuccess(bucket, response);
      _notifySafely();
    } catch (error) {
      if (_isStaleRequest(bucket, requestId)) {
        return;
      }
      _applyLoadMoreFailure(bucket, error);
      _notifySafely();
    }
  }

  void openDetail(ResourceTaskRecordDto record) {
    if (_selectedRecord?.recordKey == record.recordKey) {
      return;
    }
    _selectedRecord = record;
    _notifySafely();
  }

  void closeDetail() {
    if (_selectedRecord == null) {
      return;
    }
    _selectedRecord = null;
    _notifySafely();
  }

  Future<void> _loadFirstPage(String taskKey) async {
    final bucket = _ensureBucket(taskKey);
    final requestId = ++bucket.loadRequestId;
    _startInitialLoad(bucket);
    _notifySafely();

    try {
      final response = await _fetchRecordsPage(
        taskKey,
        page: 1,
        bucket: bucket,
      );

      if (_isStaleRequest(bucket, requestId)) {
        return;
      }

      _applyInitialLoadSuccess(bucket, response);
      _notifySafely();
    } catch (error) {
      if (_isStaleRequest(bucket, requestId)) {
        return;
      }
      _applyInitialLoadFailure(bucket, error);
      _notifySafely();
    }
  }

  Future<PaginatedResponseDto<ResourceTaskRecordDto>> _fetchRecordsPage(
    String taskKey, {
    required int page,
    required _RecordsBucket bucket,
  }) {
    return _activityApi.getResourceTaskRecords(
      taskKey: taskKey,
      page: page,
      pageSize: _pageSize,
      state: bucket.filter.stateFilter.apiValue,
      search: _normalizedSearch(bucket.filter),
      sort: bucket.filter.sort.apiValue,
    );
  }

  String? _normalizedSearch(ResourceTaskRecordFilterState filter) {
    return filter.normalizedSearch.isEmpty ? null : filter.normalizedSearch;
  }

  bool _isStaleRequest(_RecordsBucket bucket, int requestId) {
    return _disposed || requestId != bucket.loadRequestId;
  }

  void _startInitialLoad(_RecordsBucket bucket) {
    bucket.isLoading = true;
    bucket.loadErrorMessage = null;
    bucket.loadMoreErrorMessage = null;
  }

  void _startLoadMore(_RecordsBucket bucket) {
    bucket.isLoadingMore = true;
    bucket.loadMoreErrorMessage = null;
  }

  void _applyInitialLoadSuccess(
    _RecordsBucket bucket,
    PaginatedResponseDto<ResourceTaskRecordDto> response,
  ) {
    bucket.records = List<ResourceTaskRecordDto>.unmodifiable(response.items);
    _applyPagination(bucket, response, currentCount: bucket.records.length);
    bucket.isLoading = false;
    bucket.hasLoadedOnce = true;
  }

  void _applyLoadMoreSuccess(
    _RecordsBucket bucket,
    PaginatedResponseDto<ResourceTaskRecordDto> response,
  ) {
    bucket.records = <ResourceTaskRecordDto>[
      ...bucket.records,
      ...response.items,
    ];
    bucket.isLoadingMore = false;
    _applyPagination(bucket, response, currentCount: bucket.records.length);
  }

  void _applyPagination(
    _RecordsBucket bucket,
    PaginatedResponseDto<ResourceTaskRecordDto> response, {
    required int currentCount,
  }) {
    bucket.nextPage = response.page + 1;
    bucket.hasMore =
        response.items.length >= response.pageSize &&
        currentCount < response.total;
  }

  void _applyInitialLoadFailure(_RecordsBucket bucket, Object error) {
    bucket.isLoading = false;
    bucket.loadErrorMessage = apiErrorMessage(
      error,
      fallback: '资源任务记录加载失败，请稍后重试',
    );
  }

  void _applyLoadMoreFailure(_RecordsBucket bucket, Object error) {
    bucket.isLoadingMore = false;
    bucket.loadMoreErrorMessage = apiErrorMessage(
      error,
      fallback: '加载更多失败，请稍后重试',
    );
  }

  _RecordsBucket _ensureBucket(String taskKey) {
    return _buckets.putIfAbsent(taskKey, _RecordsBucket.new);
  }

  _RecordsBucket? _bucketFor(String? taskKey) {
    if (taskKey == null) {
      return null;
    }
    return _buckets[taskKey];
  }

  void _notifySafely() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
