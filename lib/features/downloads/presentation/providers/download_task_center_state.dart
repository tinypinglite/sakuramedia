import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/features/downloads/presentation/download_task_filter_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

@immutable
class DownloadClientOption {
  const DownloadClientOption({required this.id, required this.name});

  final int id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is DownloadClientOption && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

enum DownloadTaskPollingState { idle, polling }

@immutable
class DownloadTaskRowState {
  const DownloadTaskRowState({required this.task});

  final DownloadTaskDto task;

  double get progress => task.progress;
  String get state => task.state;

  /// 行级相等：轮询快照用它判断某行是否实质变化，未变行不重建。
  ///
  /// 只比展示相关字段（封面比 origin，`resultSummary` 之类的深结构不在行内展示）；
  /// 漏比只会导致多一次重建（现状），不会漏更新。
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DownloadTaskRowState &&
        other.task.id == task.id &&
        other.task.clientId == task.clientId &&
        other.task.movieNumber == task.movieNumber &&
        other.task.name == task.name &&
        other.task.remoteId == task.remoteId &&
        other.task.state == task.state &&
        other.task.progress == task.progress &&
        other.task.importStatus == task.importStatus &&
        other.task.importStatusLabel == task.importStatusLabel &&
        other.task.blacklistable == task.blacklistable &&
        other.task.createdAt == task.createdAt &&
        other.task.updatedAt == task.updatedAt &&
        other.task.movieTitle == task.movieTitle &&
        other.task.movieCover?.origin == task.movieCover?.origin &&
        other.task.movieThinCover?.origin == task.movieThinCover?.origin &&
        other.task.displayName == task.displayName;
  }

  @override
  int get hashCode => Object.hash(
    task.id,
    task.state,
    task.progress,
    task.importStatus,
    task.blacklistable,
    task.updatedAt,
  );
}

@immutable
class DownloadTaskCenterState {
  const DownloadTaskCenterState({
    required this.paged,
    required this.filter,
    this.pollingState = DownloadTaskPollingState.idle,
    this.clientOptions = const <DownloadClientOption>[],
    this.clientNames = const <int, String>{},
    this.pendingActionTaskIds = const <int>{},
    this.selectionMode = false,
    this.selectedTaskIds = const <int>{},
  });

  static final DownloadTaskCenterState initial = DownloadTaskCenterState(
    paged: const PagedListState<DownloadTaskRowState>(),
    filter: DownloadTaskFilterState.initial,
  );

  final PagedListState<DownloadTaskRowState> paged;
  final DownloadTaskFilterState filter;
  final DownloadTaskPollingState pollingState;
  final List<DownloadClientOption> clientOptions;
  final Map<int, String> clientNames;
  final Set<int> pendingActionTaskIds;

  /// 多选态：进入后行卡片整卡点击 = 勾选，行内动作与详情跳转让位。
  final bool selectionMode;
  final Set<int> selectedTaskIds;

  int get selectionCount => selectedTaskIds.length;

  bool get hasSelection => selectedTaskIds.isNotEmpty;

  bool isSelected(int taskId) => selectedTaskIds.contains(taskId);

  bool isTaskPending(int taskId) => pendingActionTaskIds.contains(taskId);

  DownloadTaskCenterState copyWith({
    PagedListState<DownloadTaskRowState>? paged,
    DownloadTaskFilterState? filter,
    DownloadTaskPollingState? pollingState,
    List<DownloadClientOption>? clientOptions,
    Map<int, String>? clientNames,
    Set<int>? pendingActionTaskIds,
    bool? selectionMode,
    Set<int>? selectedTaskIds,
  }) {
    return DownloadTaskCenterState(
      paged: paged ?? this.paged,
      filter: filter ?? this.filter,
      pollingState: pollingState ?? this.pollingState,
      clientOptions: clientOptions ?? this.clientOptions,
      clientNames: clientNames ?? this.clientNames,
      pendingActionTaskIds: pendingActionTaskIds ?? this.pendingActionTaskIds,
      selectionMode: selectionMode ?? this.selectionMode,
      selectedTaskIds: selectedTaskIds ?? this.selectedTaskIds,
    );
  }

  /// 内容相等：Riverpod 默认按 `==` 决定要不要通知订阅者（`updateShouldNotify`），
  /// 全等时跳过通知，30 秒轮询 tick 无实质变化就不会凭空重建整页。
  /// 必须覆盖全部字段：漏比的字段会静默丢掉该字段的更新。
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DownloadTaskCenterState &&
        _samePaged(other.paged, paged) &&
        other.filter == filter &&
        other.pollingState == pollingState &&
        listEquals(other.clientOptions, clientOptions) &&
        mapEquals(other.clientNames, clientNames) &&
        setEquals(other.pendingActionTaskIds, pendingActionTaskIds) &&
        other.selectionMode == selectionMode &&
        setEquals(other.selectedTaskIds, selectedTaskIds);
  }

  @override
  int get hashCode => Object.hash(
    filter,
    pollingState,
    selectionMode,
    Object.hashAll(clientOptions),
    Object.hashAllUnordered(
      clientNames.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    Object.hashAllUnordered(pendingActionTaskIds),
    Object.hashAllUnordered(selectedTaskIds),
    paged.currentPage,
    paged.total,
    paged.hasMore,
    paged.filterUpdate,
    paged.isLoadingMore,
    paged.loadMoreErrorMessage,
    Object.hashAll(paged.items),
  );

  /// [PagedListState] 的相等但不比 `syncedAt`：下载列表不展示该时间戳，
  /// 而每轮轮询都会刷新它（比了就等于每轮都通知）。
  static bool _samePaged(
    PagedListState<DownloadTaskRowState> a,
    PagedListState<DownloadTaskRowState> b,
  ) {
    return a.currentPage == b.currentPage &&
        a.total == b.total &&
        a.hasMore == b.hasMore &&
        a.filterUpdate == b.filterUpdate &&
        a.isLoadingMore == b.isLoadingMore &&
        a.loadMoreErrorMessage == b.loadMoreErrorMessage &&
        listEquals(a.items, b.items);
  }
}
