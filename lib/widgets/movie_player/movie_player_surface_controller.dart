import 'dart:async';

import 'package:flutter/foundation.dart';

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
    debugPrint(
      '[player-debug] surface_controller_seek_to seconds=${position.inSeconds}',
    );
    _seekController.add(position);
  }

  void play() {
    if (_playController.isClosed) {
      return;
    }
    debugPrint('[player-debug] surface_controller_play');
    _playController.add(null);
  }

  void dispose() {
    _seekController.close();
    _playController.close();
  }
}
