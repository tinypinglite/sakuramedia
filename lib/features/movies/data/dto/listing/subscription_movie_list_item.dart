abstract interface class SubscriptionMovieListItem<T> {
  String get movieNumber;
  bool get isSubscribed;

  T copyWithSubscriptionStatus(bool isSubscribed);
}
