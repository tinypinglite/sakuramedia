import 'package:flutter/foundation.dart';

class MovieSubscriptionChange {
  const MovieSubscriptionChange({
    required this.movieNumber,
    required this.isSubscribed,
  });

  final String movieNumber;
  final bool isSubscribed;
}

class MovieSubscriptionChangeNotifier extends ChangeNotifier {
  MovieSubscriptionChange? _lastChange;
  MovieSubscriptionChange? get lastChange => _lastChange;

  void reportChange({required String movieNumber, required bool isSubscribed}) {
    _lastChange = MovieSubscriptionChange(
      movieNumber: movieNumber,
      isSubscribed: isSubscribed,
    );
    notifyListeners();
  }
}
