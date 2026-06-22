import 'package:sakuramedia/features/actors/presentation/actor_filter_state.dart';

/// 移动端演员 tab 顶部 chip 的「快速筛选预设」。
///
/// 注意：`ActorFilterState.initial.subscriptionStatus == subscribed`（默认看已订阅），
/// 与「全部」语义有别——「全部」preset 显式置 `subscriptionStatus: all`。
/// 性别筛选不在 chip 暴露（如需可走右上筛选抽屉里的「性别筛选」section）。
enum ActorFilterPreset { mySubscribed, all }

extension ActorFilterPresetX on ActorFilterPreset {
  String get key => switch (this) {
    ActorFilterPreset.mySubscribed => 'my-subscribed',
    ActorFilterPreset.all => 'all',
  };

  String get label => switch (this) {
    ActorFilterPreset.mySubscribed => '我的订阅',
    ActorFilterPreset.all => '全部',
  };

  ActorFilterState get filterState => switch (this) {
    ActorFilterPreset.mySubscribed => const ActorFilterState(),
    ActorFilterPreset.all => const ActorFilterState(
      subscriptionStatus: ActorSubscriptionStatus.all,
    ),
  };
}

extension ActorFilterStatePresetMatch on ActorFilterState {
  bool matches(ActorFilterState other) =>
      subscriptionStatus == other.subscriptionStatus &&
      gender == other.gender &&
      sortField == other.sortField &&
      sortDirection == other.sortDirection;

  bool matchesPreset(ActorFilterPreset preset) => matches(preset.filterState);
}
