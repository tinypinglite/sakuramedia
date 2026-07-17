import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_task_stream_event_dto.dart';
import 'package:sakuramedia/features/downloads/presentation/download_task_filter_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

/// 供筛选栏下拉展示的下载客户端选项：id + 展示名。
@immutable
class DownloadClientOption {
  const DownloadClientOption({
    required this.id,
    required this.name,
    required this.kind,
  });

  final int id;
  final String name;
  final DownloadClientKind kind;

  @override
  bool operator ==(Object other) {
    return other is DownloadClientOption &&
        other.id == id &&
        other.name == name &&
        other.kind == kind;
  }

  @override
  int get hashCode => Object.hash(id, name, kind);
}

/// 下载任务的实时连接状态。
///
/// - [idle]: 页面未进入下载 tab，未连接（活动中心切走后进入此态，保留列表快照）。
/// - [connecting]: 首次连接中。
/// - [live]: 正常收流。
/// - [reconnecting]: 断线，退避重连中。
/// - [polling]: SSE 不受支持（主要 Web 端），30s 轮询兜底。
enum DownloadTaskStreamState { idle, connecting, live, reconnecting, polling }

/// 单个任务的行状态：`task` 打底 + `live` 覆盖实时字段。
@immutable
class DownloadTaskRowState {
  const DownloadTaskRowState({required this.task, this.live});

  final DownloadTaskDto task;
  final DownloadTaskProgressDto? live;

  DownloadTaskRowState copyWith({
    DownloadTaskDto? task,
    Object? live = _sentinel,
  }) {
    return DownloadTaskRowState(
      task: task ?? this.task,
      live: identical(live, _sentinel)
          ? this.live
          : live as DownloadTaskProgressDto?,
    );
  }

  double get progress => live?.progress ?? task.progress;
  String get downloadState => live?.downloadState ?? task.downloadState;
}

/// 单个客户端的实时传输 + 健康状态。
@immutable
class DownloadClientTransferState {
  const DownloadClientTransferState({
    required this.clientId,
    this.downloadSpeedBytes = 0,
    this.uploadSpeedBytes = 0,
    this.isAvailable = true,
    this.unavailableMessage,
  });

  final int clientId;
  final int downloadSpeedBytes;
  final int uploadSpeedBytes;
  final bool isAvailable;
  final String? unavailableMessage;

  DownloadClientTransferState copyWith({
    int? downloadSpeedBytes,
    int? uploadSpeedBytes,
    bool? isAvailable,
    Object? unavailableMessage = _sentinel,
  }) {
    return DownloadClientTransferState(
      clientId: clientId,
      downloadSpeedBytes: downloadSpeedBytes ?? this.downloadSpeedBytes,
      uploadSpeedBytes: uploadSpeedBytes ?? this.uploadSpeedBytes,
      isAvailable: isAvailable ?? this.isAvailable,
      unavailableMessage: identical(unavailableMessage, _sentinel)
          ? this.unavailableMessage
          : unavailableMessage as String?,
    );
  }
}

const Object _sentinel = Object();

/// 「下载中心」组合 State：分页列表 + 筛选 + SSE 状态 + 客户端映射 + 进行中动作。
///
/// - [paged] 由 [PagedAsyncNotifierMixin] 维护。
/// - [filter] 走「筛选状态驱动」范式；改后由 notifier 走独立 reload 路径（非
///   mixin.reload，保留旧 items + LinearProgressIndicator 反馈）。
/// - [streamState] / [clientTransfers] / [clientOptions] / [clientNames] /
///   [clientKinds] / [pendingActionTaskIds] / [isReloading] 是 UI 观察字段，
///   由 notifier 内部字段/timer/subscription 驱动它们变更。
@immutable
class DownloadTaskCenterState {
  const DownloadTaskCenterState({
    required this.paged,
    required this.filter,
    this.streamState = DownloadTaskStreamState.idle,
    this.clientTransfers = const <int, DownloadClientTransferState>{},
    this.clientOptions = const <DownloadClientOption>[],
    this.clientNames = const <int, String>{},
    this.clientKinds = const <int, DownloadClientKind>{},
    this.pendingActionTaskIds = const <int>{},
    this.isReloading = false,
  });

  static final DownloadTaskCenterState initial = DownloadTaskCenterState(
    paged: const PagedListState<DownloadTaskRowState>(),
    filter: DownloadTaskFilterState.initial,
  );

  final PagedListState<DownloadTaskRowState> paged;
  final DownloadTaskFilterState filter;
  final DownloadTaskStreamState streamState;
  final Map<int, DownloadClientTransferState> clientTransfers;
  final List<DownloadClientOption> clientOptions;
  final Map<int, String> clientNames;
  final Map<int, DownloadClientKind> clientKinds;
  final Set<int> pendingActionTaskIds;
  final bool isReloading;

  bool isTaskPending(int taskId) => pendingActionTaskIds.contains(taskId);

  String clientNameOf(int clientId) =>
      clientNames[clientId] ?? '客户端 #$clientId';

  DownloadClientKind clientKindOf(int clientId) =>
      clientKinds[clientId] ?? DownloadClientKind.qbittorrent;

  int get totalDownloadSpeedBytes {
    var total = 0;
    for (final entry in clientTransfers.values) {
      if (entry.isAvailable) total += entry.downloadSpeedBytes;
    }
    return total;
  }

  int get totalUploadSpeedBytes {
    var total = 0;
    for (final entry in clientTransfers.values) {
      if (entry.isAvailable) total += entry.uploadSpeedBytes;
    }
    return total;
  }

  DownloadTaskCenterState copyWith({
    PagedListState<DownloadTaskRowState>? paged,
    DownloadTaskFilterState? filter,
    DownloadTaskStreamState? streamState,
    Map<int, DownloadClientTransferState>? clientTransfers,
    List<DownloadClientOption>? clientOptions,
    Map<int, String>? clientNames,
    Map<int, DownloadClientKind>? clientKinds,
    Set<int>? pendingActionTaskIds,
    bool? isReloading,
  }) {
    return DownloadTaskCenterState(
      paged: paged ?? this.paged,
      filter: filter ?? this.filter,
      streamState: streamState ?? this.streamState,
      clientTransfers: clientTransfers ?? this.clientTransfers,
      clientOptions: clientOptions ?? this.clientOptions,
      clientNames: clientNames ?? this.clientNames,
      clientKinds: clientKinds ?? this.clientKinds,
      pendingActionTaskIds: pendingActionTaskIds ?? this.pendingActionTaskIds,
      isReloading: isReloading ?? this.isReloading,
    );
  }
}
