import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/widgets/base/media/video/initial_seek_guard.dart';

void main() {
  test('waits for first frame and real playback progress', () async {
    final firstFrame = Completer<void>();
    final positions = StreamController<Duration>.broadcast(sync: true);
    var currentPosition = Duration.zero;
    var playing = true;
    var buffering = false;
    var completed = false;

    final future = waitUntilInitialSeekReady(
      firstFrame: firstFrame.future,
      positionStream: positions.stream,
      currentPosition: () => currentPosition,
      isPlaying: () => playing,
      isBuffering: () => buffering,
      stabilizationTimeout: const Duration(seconds: 1),
    )..then((_) => completed = true);

    currentPosition = const Duration(seconds: 10);
    positions.add(currentPosition);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    firstFrame.complete();
    await Future<void>.delayed(Duration.zero);
    currentPosition = const Duration(milliseconds: 10499);
    positions.add(currentPosition);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    currentPosition = const Duration(milliseconds: 10500);
    positions.add(currentPosition);
    await future;
    expect(completed, isTrue);

    await positions.close();
  });

  test('does not unlock while player is buffering', () async {
    final positions = StreamController<Duration>.broadcast(sync: true);
    var currentPosition = Duration.zero;
    var buffering = true;
    var completed = false;

    final future = waitUntilInitialSeekReady(
      firstFrame: Future<void>.value(),
      positionStream: positions.stream,
      currentPosition: () => currentPosition,
      isPlaying: () => true,
      isBuffering: () => buffering,
      stabilizationTimeout: const Duration(seconds: 1),
    )..then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);

    currentPosition = const Duration(seconds: 1);
    positions.add(currentPosition);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    buffering = false;
    positions.add(currentPosition);
    await future;
    expect(completed, isTrue);

    await positions.close();
  });

  test(
    'timeout prevents a stalled player from locking controls forever',
    () async {
      final positions = StreamController<Duration>.broadcast();

      await waitUntilInitialSeekReady(
        firstFrame: Future<void>.value(),
        positionStream: positions.stream,
        currentPosition: () => Duration.zero,
        isPlaying: () => false,
        isBuffering: () => true,
        stabilizationTimeout: const Duration(milliseconds: 10),
      );

      await positions.close();
    },
  );
}
