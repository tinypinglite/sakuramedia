class ActivityNotificationFilterState {
  const ActivityNotificationFilterState({this.category});

  static const ActivityNotificationFilterState initial =
      ActivityNotificationFilterState(category: 'reminder');

  final String? category;

  ActivityNotificationFilterState copyWith({Object? category = _sentinel}) {
    return ActivityNotificationFilterState(
      category:
          identical(category, _sentinel) ? this.category : category as String?,
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

extension ActivityTaskSortValue on ActivityTaskSort {
  String get label => switch (this) {
    ActivityTaskSort.startedAtDesc => '开始时间：新到旧',
    ActivityTaskSort.startedAtAsc => '开始时间：旧到新',
    ActivityTaskSort.createdAtDesc => '创建时间：新到旧',
    ActivityTaskSort.createdAtAsc => '创建时间：旧到新',
    ActivityTaskSort.updatedAtDesc => '更新时间：新到旧',
    ActivityTaskSort.updatedAtAsc => '更新时间：旧到新',
  };

  String get apiValue => switch (this) {
    ActivityTaskSort.startedAtDesc => 'started_at:desc',
    ActivityTaskSort.startedAtAsc => 'started_at:asc',
    ActivityTaskSort.createdAtDesc => 'created_at:desc',
    ActivityTaskSort.createdAtAsc => 'created_at:asc',
    ActivityTaskSort.updatedAtDesc => 'updated_at:desc',
    ActivityTaskSort.updatedAtAsc => 'updated_at:asc',
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

  ActivityTaskFilterState copyWith({
    Object? state = _sentinel,
    Object? taskKey = _sentinel,
    Object? triggerType = _sentinel,
    ActivityTaskSort? sort,
  }) {
    return ActivityTaskFilterState(
      state: identical(state, _sentinel) ? this.state : state as String?,
      taskKey:
          identical(taskKey, _sentinel) ? this.taskKey : taskKey as String?,
      triggerType:
          identical(triggerType, _sentinel)
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
