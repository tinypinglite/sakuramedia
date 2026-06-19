import 'package:flutter/foundation.dart';

class MoviePlayabilityChange {
  const MoviePlayabilityChange({
    required this.movieNumber,
    required this.canPlay,
  });

  final String movieNumber;
  final bool canPlay;
}

class MoviePlayabilityChangeNotifier extends ChangeNotifier {
  MoviePlayabilityChange? _lastChange;
  MoviePlayabilityChange? get lastChange => _lastChange;

  void reportChange({required String movieNumber, required bool canPlay}) {
    _lastChange = MoviePlayabilityChange(
      movieNumber: movieNumber,
      canPlay: canPlay,
    );
    notifyListeners();
  }
}
