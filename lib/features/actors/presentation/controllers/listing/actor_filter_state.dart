import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/shared/data/sort_direction.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

enum ActorSubscriptionStatus { all, subscribed, unsubscribed }

extension ActorSubscriptionStatusX on ActorSubscriptionStatus {
  String get apiValue => switch (this) {
    ActorSubscriptionStatus.all => 'all',
    ActorSubscriptionStatus.subscribed => 'subscribed',
    ActorSubscriptionStatus.unsubscribed => 'unsubscribed',
  };

  /// 筛选标签。调用方负责传入当前语言的 [AppLocalizations]。
  String label(AppLocalizations l10n) => switch (this) {
    ActorSubscriptionStatus.all => l10n.actorSubscriptionStatusAll,
    ActorSubscriptionStatus.subscribed =>
      l10n.actorSubscriptionStatusSubscribed,
    ActorSubscriptionStatus.unsubscribed =>
      l10n.actorSubscriptionStatusUnsubscribed,
  };
}

enum ActorGender { all, female, male }

extension ActorGenderX on ActorGender {
  String get apiValue => switch (this) {
    ActorGender.all => 'all',
    ActorGender.female => 'female',
    ActorGender.male => 'male',
  };

  /// 筛选标签。调用方负责传入当前语言的 [AppLocalizations]。
  String label(AppLocalizations l10n) => switch (this) {
    ActorGender.all => l10n.actorGenderAll,
    ActorGender.female => l10n.actorGenderFemale,
    ActorGender.male => l10n.actorGenderMale,
  };
}

enum ActorSortField {
  subscribedAt,
  name,
  movieCount,
  playableMovieCount,
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
    ActorSortField.playableMovieCount => 'playable_movie_count',
    ActorSortField.age => 'age',
    ActorSortField.heightCm => 'height_cm',
    ActorSortField.bustCm => 'bust_cm',
    ActorSortField.waistCm => 'waist_cm',
    ActorSortField.hipsCm => 'hips_cm',
    ActorSortField.waistHipRatio => 'waist_hip_ratio',
    ActorSortField.cup => 'cup',
  };

  /// 排序字段标签。调用方负责传入当前语言的 [AppLocalizations]。
  String label(AppLocalizations l10n) => switch (this) {
    ActorSortField.subscribedAt => l10n.actorSortFieldSubscribedAt,
    ActorSortField.name => l10n.actorSortFieldName,
    ActorSortField.movieCount => l10n.actorSortFieldMovieCount,
    ActorSortField.playableMovieCount => l10n.actorSortFieldPlayableMovieCount,
    ActorSortField.age => l10n.actorSortFieldAge,
    ActorSortField.heightCm => l10n.actorSortFieldHeight,
    ActorSortField.bustCm => l10n.actorSortFieldBust,
    ActorSortField.waistCm => l10n.actorSortFieldWaist,
    ActorSortField.hipsCm => l10n.actorSortFieldHips,
    ActorSortField.waistHipRatio => l10n.actorSortFieldWaistHipRatio,
    ActorSortField.cup => l10n.actorSortFieldCup,
  };
}

@immutable
class ActorFilterState {
  const ActorFilterState({
    this.subscriptionStatus = ActorSubscriptionStatus.subscribed,
    this.gender = ActorGender.all,
    this.hasPlayableMovies = false,
    this.query,
    this.sortField = ActorSortField.subscribedAt,
    this.sortDirection = SortDirection.desc,
    this.ageMin,
    this.ageMax,
    this.heightMin,
    this.heightMax,
    this.cups = const <String>[],
  });

  final ActorSubscriptionStatus subscriptionStatus;
  final ActorGender gender;

  /// 只看存在可播放影片的女优；接口参数 `has_playable_movies`。
  final bool hasPlayableMovies;

  /// 关键词搜索；`null` 表示不搜索。调用方保证已去空白。
  final String? query;
  final ActorSortField sortField;
  final SortDirection sortDirection;
  final int? ageMin;
  final int? ageMax;
  final int? heightMin;
  final int? heightMax;
  final List<String> cups;

  static const ActorFilterState initial = ActorFilterState();

  /// 是否存在生效的筛选条件。
  ///
  /// **不含排序**：排序是视图偏好，不是筛选条件；「重置筛选」、空态文案和
  /// 口味推荐条都只应看这里。
  bool get hasActiveFilters =>
      subscriptionStatus != ActorSubscriptionStatus.subscribed ||
      gender != ActorGender.all ||
      hasPlayableMovies ||
      query != null ||
      ageMin != null ||
      ageMax != null ||
      heightMin != null ||
      heightMax != null ||
      cups.isNotEmpty;

  bool get isSearching => query != null;

  /// 搜索且仍使用默认字段时，后端按相关度排序。
  bool get usesRelevanceSort =>
      isSearching && sortField == ActorSortField.subscribedAt;

  /// 重置筛选条件但保留当前排序。
  ActorFilterState resetFilters() => ActorFilterState.initial.copyWith(
    sortField: sortField,
    sortDirection: sortDirection,
  );

  String get sortExpression =>
      '${sortField.apiValue}:${sortDirection.apiValue}';

  /// 只反映订阅状态这一主维度；性别 / 排序有独立分节，不堆在入口上。
  /// 语义对齐 `MovieFilterState.triggerLabel`。
  ///
  /// 调用方负责传入当前语言的 [AppLocalizations]。
  String triggerLabel(AppLocalizations l10n) => subscriptionStatus.label(l10n);

  /// 女优搜索入口专用：从无关键词开始搜索时把默认的「已订阅」放宽为「全部」，
  /// 避免在订阅视图下搜不到未订阅女优；搜索过程中继续输入不覆盖用户改过的筛选。
  ActorFilterState withSearchQuery(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return copyWith(query: null);
    }
    final isStartingSearch = (query ?? '').isEmpty;
    return copyWith(
      query: trimmed,
      subscriptionStatus:
          isStartingSearch &&
              subscriptionStatus == ActorSubscriptionStatus.subscribed
          ? ActorSubscriptionStatus.all
          : subscriptionStatus,
    );
  }

  ActorFilterState copyWith({
    ActorSubscriptionStatus? subscriptionStatus,
    ActorGender? gender,
    bool? hasPlayableMovies,
    Object? query = _unset,
    ActorSortField? sortField,
    SortDirection? sortDirection,
    Object? ageMin = _unset,
    Object? ageMax = _unset,
    Object? heightMin = _unset,
    Object? heightMax = _unset,
    List<String>? cups,
  }) {
    return ActorFilterState(
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      gender: gender ?? this.gender,
      hasPlayableMovies: hasPlayableMovies ?? this.hasPlayableMovies,
      query: identical(query, _unset) ? this.query : query as String?,
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
        other.hasPlayableMovies == hasPlayableMovies &&
        other.query == query &&
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
    hasPlayableMovies,
    query,
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
