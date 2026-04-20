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

class ActorFilterState {
  const ActorFilterState({
    this.subscriptionStatus = ActorSubscriptionStatus.subscribed,
    this.gender = ActorGender.all,
  });

  final ActorSubscriptionStatus subscriptionStatus;
  final ActorGender gender;

  static const ActorFilterState initial = ActorFilterState();

  bool get isDefault =>
      subscriptionStatus == ActorSubscriptionStatus.subscribed &&
      gender == ActorGender.all;

  ActorFilterState copyWith({
    ActorSubscriptionStatus? subscriptionStatus,
    ActorGender? gender,
  }) {
    return ActorFilterState(
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      gender: gender ?? this.gender,
    );
  }
}
