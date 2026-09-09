import 'package:flutter/foundation.dart';

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

enum ActorSortField {
  subscribedAt,
  name,
  movieCount,
  age,
  heightCm,
  bustCm,
  waistCm,
  hipsCm,
  waistHipRatio,
  cup,
}

extension ActorSortFieldX on ActorSortField {
  String get apiValue => switch (this) {
    ActorSortField.subscribedAt => 'subscribed_at',
    ActorSortField.name => 'name',
    ActorSortField.movieCount => 'movie_count',
    ActorSortField.age => 'age',
    ActorSortField.heightCm => 'height_cm',
    ActorSortField.bustCm => 'bust_cm',
    ActorSortField.waistCm => 'waist_cm',
    ActorSortField.hipsCm => 'hips_cm',
    ActorSortField.waistHipRatio => 'waist_hip_ratio',
    ActorSortField.cup => 'cup',
  };

  String get label => switch (this) {
    ActorSortField.subscribedAt => '最近订阅',
    ActorSortField.name => '名称',
    ActorSortField.movieCount => '影片数',
    ActorSortField.age => '年龄',
    ActorSortField.heightCm => '身高',
    ActorSortField.bustCm => '胸围',
    ActorSortField.waistCm => '腰围',
    ActorSortField.hipsCm => '臀围',
    ActorSortField.waistHipRatio => '腰臀比',
    ActorSortField.cup => '罩杯',
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

@immutable
class ActorFilterState {
  const ActorFilterState({
    this.subscriptionStatus = ActorSubscriptionStatus.subscribed,
    this.gender = ActorGender.all,
    this.sortField = ActorSortField.subscribedAt,
    this.sortDirection = ActorSortDirection.desc,
    this.ageMin,
    this.ageMax,
    this.heightMin,
    this.heightMax,
    this.cups = const <String>[],
  });

  final ActorSubscriptionStatus subscriptionStatus;
  final ActorGender gender;
  final ActorSortField sortField;
  final ActorSortDirection sortDirection;
  final int? ageMin;
  final int? ageMax;
  final int? heightMin;
  final int? heightMax;
  final List<String> cups;

  static const ActorFilterState initial = ActorFilterState();

  bool get isDefault =>
      subscriptionStatus == ActorSubscriptionStatus.subscribed &&
      gender == ActorGender.all &&
      sortField == ActorSortField.subscribedAt &&
      sortDirection == ActorSortDirection.desc &&
      ageMin == null &&
      ageMax == null &&
      heightMin == null &&
      heightMax == null &&
      cups.isEmpty;

  String get sortExpression =>
      '${sortField.apiValue}:${sortDirection.apiValue}';

  /// 只反映订阅状态这一主维度；性别 / 排序有独立分节，不堆在入口上。
  /// 语义对齐 `MovieFilterState.triggerLabel`。
  String get triggerLabel => subscriptionStatus.label;

  ActorFilterState copyWith({
    ActorSubscriptionStatus? subscriptionStatus,
    ActorGender? gender,
    ActorSortField? sortField,
    ActorSortDirection? sortDirection,
    Object? ageMin = _unset,
    Object? ageMax = _unset,
    Object? heightMin = _unset,
    Object? heightMax = _unset,
    List<String>? cups,
  }) {
    return ActorFilterState(
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      gender: gender ?? this.gender,
      sortField: sortField ?? this.sortField,
      sortDirection: sortDirection ?? this.sortDirection,
      ageMin: identical(ageMin, _unset) ? this.ageMin : ageMin as int?,
      ageMax: identical(ageMax, _unset) ? this.ageMax : ageMax as int?,
      heightMin: identical(heightMin, _unset)
          ? this.heightMin
          : heightMin as int?,
      heightMax: identical(heightMax, _unset)
          ? this.heightMax
          : heightMax as int?,
      cups: cups ?? this.cups,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ActorFilterState &&
        other.subscriptionStatus == subscriptionStatus &&
        other.gender == gender &&
        other.sortField == sortField &&
        other.sortDirection == sortDirection &&
        other.ageMin == ageMin &&
        other.ageMax == ageMax &&
        other.heightMin == heightMin &&
        other.heightMax == heightMax &&
        listEquals(other.cups, cups);
  }

  @override
  int get hashCode => Object.hash(
    subscriptionStatus,
    gender,
    sortField,
    sortDirection,
    ageMin,
    ageMax,
    heightMin,
    heightMax,
    Object.hashAll(cups),
  );
}

const Object _unset = Object();
