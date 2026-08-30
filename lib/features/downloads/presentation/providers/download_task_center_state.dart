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

  bool isTaskPending(int taskId) => pendingActionTaskIds.contains(taskId);

  String clientNameOf(int clientId) =>
      clientNames[clientId] ?? '客户端 #$clientId';

  DownloadTaskCenterState copyWith({
    PagedListState<DownloadTaskRowState>? paged,
    DownloadTaskFilterState? filter,
    DownloadTaskPollingState? pollingState,
    List<DownloadClientOption>? clientOptions,
    Map<int, String>? clientNames,
    Set<int>? pendingActionTaskIds,
  }) {
    return DownloadTaskCenterState(
      paged: paged ?? this.paged,
      filter: filter ?? this.filter,
      pollingState: pollingState ?? this.pollingState,
      clientOptions: clientOptions ?? this.clientOptions,
      clientNames: clientNames ?? this.clientNames,
      pendingActionTaskIds: pendingActionTaskIds ?? this.pendingActionTaskIds,
    );
  }
}
