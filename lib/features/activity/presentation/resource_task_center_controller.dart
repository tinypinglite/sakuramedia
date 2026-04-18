import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/activity/data/activity_api.dart';
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
    _notifySafely();
    await _loadFirstPage(key);
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
    bucket.isLoadingMore = true;
    bucket.loadMoreErrorMessage = null;
    _notifySafely();

    try {
      final response = await _activityApi.getResourceTaskRecords(
        taskKey: key,
        page: bucket.nextPage,
        pageSize: _pageSize,
        state: bucket.filter.stateFilter.apiValue,
        search:
            bucket.filter.normalizedSearch.isEmpty
                ? null
                : bucket.filter.normalizedSearch,
        sort: bucket.filter.sort.apiValue,
      );

      if (_disposed || requestId != bucket.loadRequestId) {
        return;
      }

      bucket.records = <ResourceTaskRecordDto>[
        ...bucket.records,
        ...response.items,
      ];
      bucket.nextPage = response.page + 1;
      bucket.hasMore =
          response.items.length >= response.pageSize &&
          bucket.records.length < response.total;
      bucket.isLoadingMore = false;
      _notifySafely();
    } catch (error) {
      if (_disposed || requestId != bucket.loadRequestId) {
        return;
      }
      bucket.isLoadingMore = false;
      bucket.loadMoreErrorMessage = apiErrorMessage(
        error,
        fallback: '加载更多失败，请稍后重试',
      );
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
    bucket.isLoading = true;
    bucket.loadErrorMessage = null;
    bucket.loadMoreErrorMessage = null;
    _notifySafely();

    try {
      final response = await _activityApi.getResourceTaskRecords(
        taskKey: taskKey,
        page: 1,
        pageSize: _pageSize,
        state: bucket.filter.stateFilter.apiValue,
        search:
            bucket.filter.normalizedSearch.isEmpty
                ? null
                : bucket.filter.normalizedSearch,
        sort: bucket.filter.sort.apiValue,
      );

      if (_disposed || requestId != bucket.loadRequestId) {
        return;
      }

      bucket.records = List<ResourceTaskRecordDto>.unmodifiable(response.items);
      bucket.nextPage = response.page + 1;
      bucket.hasMore =
          response.items.length >= response.pageSize &&
          bucket.records.length < response.total;
      bucket.isLoading = false;
      bucket.hasLoadedOnce = true;
      _notifySafely();
    } catch (error) {
      if (_disposed || requestId != bucket.loadRequestId) {
        return;
      }
      bucket.isLoading = false;
      bucket.loadErrorMessage = apiErrorMessage(
        error,
        fallback: '资源任务记录加载失败，请稍后重试',
      );
      _notifySafely();
    }
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
