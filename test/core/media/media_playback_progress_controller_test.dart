import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/media/media_playback_progress_controller.dart';

void main() {
  test('defers reporting until the resume prompt is gone', () async {
    var shouldDefer = true;
    final reports = <({int mediaId, int positionSeconds})>[];
    final controller = MediaPlaybackProgressController(
      reportProgress: ({required mediaId, required positionSeconds}) async {
        reports.add((mediaId: mediaId, positionSeconds: positionSeconds));
      },
      resolveMediaId: () => 42,
      shouldDeferReport: () => shouldDefer,
    );
    addTearDown(controller.dispose);

    controller.handlePlaybackPosition(const Duration(seconds: 12));
    await controller.flush();
    expect(reports, isEmpty);

    shouldDefer = false;
    await controller.flush();
    expect(reports, [(mediaId: 42, positionSeconds: 12)]);
  });

  test(
    'reports only changed positive positions and retries failures',
    () async {
      var attempts = 0;
      final reports = <int>[];
      final controller = MediaPlaybackProgressController(
        reportProgress: ({required mediaId, required positionSeconds}) async {
          attempts++;
          if (attempts == 1) {
            throw StateError('temporary failure');
          }
          reports.add(positionSeconds);
        },
        resolveMediaId: () => 42,
        shouldDeferReport: () => false,
      );
      addTearDown(controller.dispose);

      await controller.flush();
      controller.handlePlaybackPosition(const Duration(seconds: 12));
      await controller.flush();
      await controller.flush();
      controller.handlePlaybackPosition(const Duration(seconds: 12));
      await controller.flush();

      expect(attempts, 2);
      expect(reports, [12]);
    },
  );

  test('periodic reporting stops when playback stops', () {
    fakeAsync((async) {
      var reportCount = 0;
      final controller = MediaPlaybackProgressController(
        reportProgress: ({required mediaId, required positionSeconds}) async {
          reportCount++;
        },
        resolveMediaId: () => 42,
        shouldDeferReport: () => false,
      );

      controller.handlePlaybackPosition(const Duration(seconds: 10));
      controller.handlePlaybackPlayingChanged(true);
      async.elapse(const Duration(seconds: 5));
      async.flushMicrotasks();
      expect(reportCount, 1);

      controller.handlePlaybackPlayingChanged(false);
      controller.handlePlaybackPosition(const Duration(seconds: 15));
      async.elapse(const Duration(seconds: 5));
      async.flushMicrotasks();
      expect(reportCount, 1);

      controller.dispose();
    });
  });
}
