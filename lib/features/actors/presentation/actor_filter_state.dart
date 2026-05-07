enum ActorSubscriptionStatus { all, subscribed, unsubscribed }

extension ActorSubscriptionStatusX on ActorSubscriptionStatus {
  String get apiValue => switch (this) {
    ActorSubscriptionStatus.all => 'all',
    ActorSubscriptionStatus.subscribed => 'subscribed',
    ActorSubscriptionStatus.unsubscribed => 'unsubscribed',
  };

  String get label => switch (this) {
    ActorSubscriptionStatus.all => '全部',
    ActorSubscriptionStatus.subscribed => '已订阅',
    ActorSubscriptionStatus.unsubscribed => '未订阅',
  };
}

enum ActorGender { all, female, male }

extension ActorGenderX on ActorGender {
  String get apiValue => switch (this) {
    ActorGender.all => 'all',
    ActorGender.female => 'female',
    ActorGender.male => 'male',
  };

  String get label => switch (this) {
    ActorGender.all => '全部',
    ActorGender.female => '女优',
    ActorGender.male => '男优',
  };
}

enum ActorSortField { subscribedAt, name, movieCount }

extension ActorSortFieldX on ActorSortField {
  String get apiValue => switch (this) {
    ActorSortField.subscribedAt => 'subscribed_at',
    ActorSortField.name => 'name',
    ActorSortField.movieCount => 'movie_count',
  };

  String get label => switch (this) {
    ActorSortField.subscribedAt => '最近订阅',
    ActorSortField.name => '名称',
    ActorSortField.movieCount => '影片数',
  };
}

enum ActorSortDirection { asc, desc }

extension ActorSortDirectionX on ActorSortDirection {
  String get apiValue => switch (this) {
    ActorSortDirection.asc => 'asc',
    ActorSortDirection.desc => 'desc',
  };

  String get label => switch (this) {
    ActorSortDirection.asc => '升序',
    ActorSortDirection.desc => '降序',
  };
}

class ActorFilterState {
  const ActorFilterState({
    this.subscriptionStatus = ActorSubscriptionStatus.subscribed,
    this.gender = ActorGender.all,
    this.sortField = ActorSortField.subscribedAt,
    this.sortDirection = ActorSortDirection.desc,
  });

  final ActorSubscriptionStatus subscriptionStatus;
  final ActorGender gender;
  final ActorSortField sortField;
  final ActorSortDirection sortDirection;

  static const ActorFilterState initial = ActorFilterState();

  bool get isDefault =>
      subscriptionStatus == ActorSubscriptionStatus.subscribed &&
      gender == ActorGender.all &&
      sortField == ActorSortField.subscribedAt &&
      sortDirection == ActorSortDirection.desc;

  String get sortExpression =>
      '${sortField.apiValue}:${sortDirection.apiValue}';

  String get triggerLabel => '${subscriptionStatus.label} · ${sortField.label}';

  ActorFilterState copyWith({
    ActorSubscriptionStatus? subscriptionStatus,
    ActorGender? gender,
    ActorSortField? sortField,
    ActorSortDirection? sortDirection,
  }) {
    return ActorFilterState(
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      gender: gender ?? this.gender,
      sortField: sortField ?? this.sortField,
      sortDirection: sortDirection ?? this.sortDirection,
    );
  }
}
