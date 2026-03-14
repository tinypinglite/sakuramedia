import 'dart:async';

class MoviePlayerSurfaceController {
  final StreamController<Duration> _seekController =
      StreamController<Duration>.broadcast();
  final StreamController<void> _playController =
      StreamController<void>.broadcast();

  Stream<Duration> get seekStream => _seekController.stream;
  Stream<void> get playStream => _playController.stream;

  void seekTo(Duration position) {
    if (_seekController.isClosed) {
      return;
    }
    _seekController.add(position);
  }

  void play() {
    if (_playController.isClosed) {
      return;
    }
    _playController.add(null);
  }

  void dispose() {
    _seekController.close();
    _playController.close();
  }
}
