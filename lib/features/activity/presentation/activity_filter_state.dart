import 'package:sakuramedia/features/activity/data/activity_api.dart';
import 'package:sakuramedia/features/shared/data/sort_direction.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

class ActivityNotificationFilterState {
  const ActivityNotificationFilterState({this.category});

  // 默认不限分类（「全部」）。
  static const ActivityNotificationFilterState initial =
      ActivityNotificationFilterState();

  final String? category;

  ActivityNotificationFilterState copyWith({Object? category = _sentinel}) {
    return ActivityNotificationFilterState(
      category: identical(category, _sentinel)
          ? this.category
          : category as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ActivityNotificationFilterState &&
        other.category == category;
  }

  @override
  int get hashCode => category.hashCode;
}

enum ActivityTaskSort {
  startedAtDesc,
  startedAtAsc,
  createdAtDesc,
  createdAtAsc,
  updatedAtDesc,
  updatedAtAsc,
}

enum ActivityTaskSortField { startedAt, createdAt, updatedAt }

extension ActivityTaskSortFieldValue on ActivityTaskSortField {
  String label(AppLocalizations l10n) => switch (this) {
    ActivityTaskSortField.startedAt => l10n.activitySortStartedAt,
    ActivityTaskSortField.createdAt => l10n.activitySortCreatedAt,
    ActivityTaskSortField.updatedAt => l10n.activitySortUpdatedAt,
  };

  ActivityTaskSort withDirection(SortDirection direction) =>
      switch ((this, direction)) {
        (ActivityTaskSortField.startedAt, SortDirection.desc) =>
          ActivityTaskSort.startedAtDesc,
        (ActivityTaskSortField.startedAt, SortDirection.asc) =>
          ActivityTaskSort.startedAtAsc,
        (ActivityTaskSortField.createdAt, SortDirection.desc) =>
          ActivityTaskSort.createdAtDesc,
        (ActivityTaskSortField.createdAt, SortDirection.asc) =>
          ActivityTaskSort.createdAtAsc,
        (ActivityTaskSortField.updatedAt, SortDirection.desc) =>
          ActivityTaskSort.updatedAtDesc,
        (ActivityTaskSortField.updatedAt, SortDirection.asc) =>
          ActivityTaskSort.updatedAtAsc,
      };
}

extension ActivityTaskSortValue on ActivityTaskSort {
  String get apiValue => switch (this) {
    ActivityTaskSort.startedAtDesc => 'started_at:desc',
    ActivityTaskSort.startedAtAsc => 'started_at:asc',
    ActivityTaskSort.createdAtDesc => 'created_at:desc',
    ActivityTaskSort.createdAtAsc => 'created_at:asc',
    ActivityTaskSort.updatedAtDesc => 'updated_at:desc',
    ActivityTaskSort.updatedAtAsc => 'updated_at:asc',
  };

  ActivityTaskSortField get field => switch (this) {
    ActivityTaskSort.startedAtDesc ||
    ActivityTaskSort.startedAtAsc => ActivityTaskSortField.startedAt,
    ActivityTaskSort.createdAtDesc ||
    ActivityTaskSort.createdAtAsc => ActivityTaskSortField.createdAt,
    ActivityTaskSort.updatedAtDesc ||
    ActivityTaskSort.updatedAtAsc => ActivityTaskSortField.updatedAt,
  };

  SortDirection get direction => switch (this) {
    ActivityTaskSort.startedAtAsc ||
    ActivityTaskSort.createdAtAsc ||
    ActivityTaskSort.updatedAtAsc => SortDirection.asc,
    _ => SortDirection.desc,
  };
}

class ActivityTaskFilterState {
  const ActivityTaskFilterState({
    this.state,
    this.taskKey,
    this.triggerType,
    this.sort = ActivityTaskSort.startedAtDesc,
  });

  static const ActivityTaskFilterState initial = ActivityTaskFilterState();

  final String? state;
  final String? taskKey;
  final String? triggerType;
  final ActivityTaskSort sort;

  ActivityTaskSortField get sortField => sort.field;
  SortDirection get sortDirection => sort.direction;

  /// 是否存在生效的筛选条件。**不含排序**。
  bool get hasActiveFilters =>
      state != null || taskKey != null || triggerType != null;

  /// 运行记录的查询范围：默认只看「操作」记录（排除定时触发的例行成功），
  /// 一旦按任务 key 或触发来源筛选就切到全量，保证筛选结果完整。
  String get taskRunScope => taskKey == null && triggerType == null
      ? ActivityTaskRunScope.operations
      : ActivityTaskRunScope.all;

  ActivityTaskFilterState withSortField(ActivityTaskSortField field) =>
      copyWith(sort: field.withDirection(sortDirection));

  ActivityTaskFilterState withSortDirection(SortDirection direction) =>
      copyWith(sort: sortField.withDirection(direction));

  /// 重置筛选条件但保留当前排序。
  ActivityTaskFilterState resetFilters() => ActivityTaskFilterState(sort: sort);

  ActivityTaskFilterState copyWith({
    Object? state = _sentinel,
    Object? taskKey = _sentinel,
    Object? triggerType = _sentinel,
    ActivityTaskSort? sort,
  }) {
    return ActivityTaskFilterState(
      state: identical(state, _sentinel) ? this.state : state as String?,
      taskKey: identical(taskKey, _sentinel)
          ? this.taskKey
          : taskKey as String?,
      triggerType: identical(triggerType, _sentinel)
          ? this.triggerType
          : triggerType as String?,
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ActivityTaskFilterState &&
        other.state == state &&
        other.taskKey == taskKey &&
        other.triggerType == triggerType &&
        other.sort == sort;
  }

  @override
  int get hashCode => Object.hash(state, taskKey, triggerType, sort);
}

const Object _sentinel = Object();
