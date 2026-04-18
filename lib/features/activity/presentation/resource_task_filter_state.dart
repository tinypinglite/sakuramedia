/// 资源任务记录的状态筛选项。`all` 表示不带 `state` 查询参数。
enum ResourceTaskRecordStateFilter { all, pending, running, succeeded, failed }

extension ResourceTaskRecordStateFilterValue on ResourceTaskRecordStateFilter {
  String get label => switch (this) {
    ResourceTaskRecordStateFilter.all => '全部',
    ResourceTaskRecordStateFilter.pending => '待处理',
    ResourceTaskRecordStateFilter.running => '运行中',
    ResourceTaskRecordStateFilter.succeeded => '已成功',
    ResourceTaskRecordStateFilter.failed => '失败',
  };

  String? get apiValue => switch (this) {
    ResourceTaskRecordStateFilter.all => null,
    ResourceTaskRecordStateFilter.pending => 'pending',
    ResourceTaskRecordStateFilter.running => 'running',
    ResourceTaskRecordStateFilter.succeeded => 'succeeded',
    ResourceTaskRecordStateFilter.failed => 'failed',
  };
}

/// 资源任务记录允许的排序项，对应后端文档允许列表。
/// `backendDefault` 表示不带 sort 参数，交由后端的 `default_sort` 决策。
enum ResourceTaskRecordSort {
  backendDefault,
  lastAttemptedAtDesc,
  lastAttemptedAtAsc,
  lastErrorAtDesc,
  attemptCountDesc,
  updatedAtDesc,
  updatedAtAsc,
}

extension ResourceTaskRecordSortValue on ResourceTaskRecordSort {
  String get label => switch (this) {
    ResourceTaskRecordSort.backendDefault => '默认',
    ResourceTaskRecordSort.lastAttemptedAtDesc => '最近尝试：新到旧',
    ResourceTaskRecordSort.lastAttemptedAtAsc => '最近尝试：旧到新',
    ResourceTaskRecordSort.lastErrorAtDesc => '最近失败：新到旧',
    ResourceTaskRecordSort.attemptCountDesc => '尝试次数：多到少',
    ResourceTaskRecordSort.updatedAtDesc => '更新时间：新到旧',
    ResourceTaskRecordSort.updatedAtAsc => '更新时间：旧到新',
  };

  String? get apiValue => switch (this) {
    ResourceTaskRecordSort.backendDefault => null,
    ResourceTaskRecordSort.lastAttemptedAtDesc => 'last_attempted_at:desc',
    ResourceTaskRecordSort.lastAttemptedAtAsc => 'last_attempted_at:asc',
    ResourceTaskRecordSort.lastErrorAtDesc => 'last_error_at:desc',
    ResourceTaskRecordSort.attemptCountDesc => 'attempt_count:desc',
    ResourceTaskRecordSort.updatedAtDesc => 'updated_at:desc',
    ResourceTaskRecordSort.updatedAtAsc => 'updated_at:asc',
  };
}

class ResourceTaskRecordFilterState {
  const ResourceTaskRecordFilterState({
    this.stateFilter = ResourceTaskRecordStateFilter.all,
    this.search = '',
    this.sort = ResourceTaskRecordSort.backendDefault,
  });

  static const ResourceTaskRecordFilterState initial =
      ResourceTaskRecordFilterState();

  final ResourceTaskRecordStateFilter stateFilter;
  final String search;
  final ResourceTaskRecordSort sort;

  String get normalizedSearch => search.trim();

  ResourceTaskRecordFilterState copyWith({
    ResourceTaskRecordStateFilter? stateFilter,
    String? search,
    ResourceTaskRecordSort? sort,
  }) {
    return ResourceTaskRecordFilterState(
      stateFilter: stateFilter ?? this.stateFilter,
      search: search ?? this.search,
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ResourceTaskRecordFilterState &&
        other.stateFilter == stateFilter &&
        other.search == search &&
        other.sort == sort;
  }

  @override
  int get hashCode => Object.hash(stateFilter, search, sort);
}
