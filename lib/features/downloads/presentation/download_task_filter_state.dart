/// 下载任务的状态筛选枚举，对应后端 `DownloadTask.download_state` 归一化后的取值。
/// `all` 表示不带 `download_state` 查询参数。
enum DownloadTaskStateFilter {
  all,
  downloading,
  seeding,
  completed,
  paused,
  failed,
  queued,
  checking,
  stalled,
  abandoned,
}

extension DownloadTaskStateFilterValue on DownloadTaskStateFilter {
  String get label => switch (this) {
        DownloadTaskStateFilter.all => '全部',
        DownloadTaskStateFilter.downloading => '下载中',
        DownloadTaskStateFilter.seeding => '做种中',
        DownloadTaskStateFilter.completed => '已完成',
        DownloadTaskStateFilter.paused => '已暂停',
        DownloadTaskStateFilter.failed => '失败',
        DownloadTaskStateFilter.queued => '排队中',
        DownloadTaskStateFilter.checking => '校验中',
        DownloadTaskStateFilter.stalled => '停滞',
        DownloadTaskStateFilter.abandoned => '已放弃跟踪',
      };

  String? get apiValue => switch (this) {
        DownloadTaskStateFilter.all => null,
        DownloadTaskStateFilter.downloading => 'downloading',
        DownloadTaskStateFilter.seeding => 'seeding',
        DownloadTaskStateFilter.completed => 'completed',
        DownloadTaskStateFilter.paused => 'paused',
        DownloadTaskStateFilter.failed => 'failed',
        DownloadTaskStateFilter.queued => 'queued',
        DownloadTaskStateFilter.checking => 'checking',
        DownloadTaskStateFilter.stalled => 'stalled',
        DownloadTaskStateFilter.abandoned => 'abandoned',
      };
}

/// 下载任务列表的筛选值对象，遵循「筛选状态驱动」范式。
/// 页面/控制器持有它作为 fetcher 闭包的输入；变更时 controller.reload() 让新参数生效。
class DownloadTaskFilterState {
  const DownloadTaskFilterState({
    this.stateFilter = DownloadTaskStateFilter.downloading,
    this.search = '',
    this.clientId,
  });

  static const DownloadTaskFilterState initial = DownloadTaskFilterState();

  final DownloadTaskStateFilter stateFilter;
  final String search;

  /// 按客户端 id 过滤；null 表示不限制客户端。仅在下载器 ≥2 个时前端会展示该筛选下拉。
  final int? clientId;

  String get normalizedSearch => search.trim();

  bool get isDefault =>
      stateFilter == DownloadTaskStateFilter.downloading &&
      normalizedSearch.isEmpty &&
      clientId == null;

  DownloadTaskFilterState copyWith({
    DownloadTaskStateFilter? stateFilter,
    String? search,
    // 用 Object 哨兵区分「不改」与「显式改成 null」：copyWith(clientId: null)
    // 目前不会走到（clientId 只增不减），但保留习惯，避免下游想改时踩坑。
    Object? clientId = _sentinel,
  }) {
    return DownloadTaskFilterState(
      stateFilter: stateFilter ?? this.stateFilter,
      search: search ?? this.search,
      clientId:
          identical(clientId, _sentinel) ? this.clientId : clientId as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DownloadTaskFilterState &&
        other.stateFilter == stateFilter &&
        other.search == search &&
        other.clientId == clientId;
  }

  @override
  int get hashCode => Object.hash(stateFilter, search, clientId);
}

const Object _sentinel = Object();
