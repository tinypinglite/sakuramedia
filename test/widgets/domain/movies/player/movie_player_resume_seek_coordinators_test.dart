import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_resume_seek_coordinators.dart';

void main() {
  group('MoviePlayerResumePromptCoordinator', () {
    late List<Duration> seeks;
    late int plays;
    late int resolvedCalls;
    late int resumeCompletedCalls;
    Duration currentPosition = Duration.zero;
    double playbackRate = 1.0;

    MoviePlayerResumePromptCoordinator build() {
      seeks = <Duration>[];
      plays = 0;
      resolvedCalls = 0;
      resumeCompletedCalls = 0;
      currentPosition = Duration.zero;
      playbackRate = 1.0;
      return MoviePlayerResumePromptCoordinator(
        seek: (position) async => seeks.add(position),
        play: () async => plays++,
        currentPosition: () => currentPosition,
        playbackRate: () => playbackRate,
        onResolved: () => resolvedCalls++,
        onResumeCompleted: () => resumeCompletedCalls++,
      );
    }

    test('beginSession 有历史位置时进入待询问,无则视为已解决', () {
      final coordinator = build();
      coordinator.beginSession(hasResumePosition: true);
      expect(coordinator.isResolved, isFalse);
      expect(coordinator.isVisible, isFalse);

      coordinator.beginSession(hasResumePosition: false);
      expect(coordinator.isResolved, isTrue);
      coordinator.dispose();
    });

    test('show 弹出提示;resolve 收起并回调一次(幂等)', () {
      final coordinator = build();
      coordinator.beginSession(hasResumePosition: true);
      coordinator.show();
      expect(coordinator.isVisible, isTrue);

      coordinator.resolve();
      expect(coordinator.isVisible, isFalse);
      expect(coordinator.isResolved, isTrue);
      expect(resolvedCalls, 1);

      coordinator.resolve();
      expect(resolvedCalls, 1);
      coordinator.dispose();
    });

    test('cancel 静默收起,不触发 onResolved', () {
      final coordinator = build();
      coordinator.beginSession(hasResumePosition: true);
      coordinator.show();

      coordinator.cancel();
      expect(coordinator.isVisible, isFalse);
      expect(coordinator.isResolved, isTrue);
      expect(resolvedCalls, 0);
      coordinator.dispose();
    });

    test('rearm 在 surface ready 时立即弹出,否则等待', () {
      final coordinator = build();
      coordinator.rearm(surfaceReady: false);
      expect(coordinator.isResolved, isFalse);
      expect(coordinator.isVisible, isFalse);

      coordinator.rearm(surfaceReady: true);
      expect(coordinator.isVisible, isTrue);
      coordinator.dispose();
    });

    test('onPosition 正常推进不收起;前跳超出容差自动 resolve', () {
      final coordinator = build();
      coordinator.beginSession(hasResumePosition: true);
      currentPosition = const Duration(seconds: 10);
      coordinator.show();

      coordinator.onPosition(const Duration(seconds: 11));
      expect(coordinator.isVisible, isTrue);

      coordinator.onPosition(const Duration(seconds: 20));
      expect(coordinator.isVisible, isFalse);
      expect(resolvedCalls, 1);
      coordinator.dispose();
    });

    test('onPosition 回退超 2s 自动 resolve', () {
      final coordinator = build();
      coordinator.beginSession(hasResumePosition: true);
      currentPosition = const Duration(seconds: 30);
      coordinator.show();

      coordinator.onPosition(const Duration(seconds: 27));
      expect(coordinator.isVisible, isFalse);
      expect(resolvedCalls, 1);
      coordinator.dispose();
    });

    test('resume 执行 seek + play 并在完成后回调 onResumeCompleted', () async {
      final coordinator = build();
      coordinator.beginSession(hasResumePosition: true);
      coordinator.show();

      coordinator.resume(const Duration(minutes: 5));
      expect(coordinator.isVisible, isFalse);
      expect(coordinator.isResolved, isTrue);

      await pumpEventQueue();
      expect(seeks, [const Duration(minutes: 5)]);
      expect(plays, 1);
      expect(resumeCompletedCalls, 1);
      expect(resolvedCalls, 0);
      coordinator.dispose();
    });

    test('resume 传 null 走 resolve 路径', () {
      final coordinator = build();
      coordinator.beginSession(hasResumePosition: true);
      coordinator.resume(null);
      expect(resolvedCalls, 1);
      coordinator.dispose();
    });

    test('resume 中 seek 抛错仍回调 onResumeCompleted', () async {
      var completed = 0;
      final coordinator = MoviePlayerResumePromptCoordinator(
        seek: (_) async => throw StateError('seek failed'),
        play: () async {},
        currentPosition: () => Duration.zero,
        playbackRate: () => 1.0,
        onResumeCompleted: () => completed++,
      );
      coordinator.beginSession(hasResumePosition: true);

      await runZonedGuarded(() async {
        coordinator.resume(const Duration(minutes: 1));
        await pumpEventQueue();
      }, (_, __) {});
      expect(completed, 1);
      coordinator.dispose();
    });
  });

  group('MoviePlayerStartupSeekCoordinator', () {
    test('无目标 / 目标为 0 时探针不工作', () {
      final seeks = <Duration>[];
      final coordinator = MoviePlayerStartupSeekCoordinator(
        seek: (position) async => seeks.add(position),
        isSurfaceReady: () => true,
      );

      coordinator.begin(null);
      coordinator.onPosition(Duration.zero);
      coordinator.begin(Duration.zero);
      coordinator.onPosition(Duration.zero);

      expect(coordinator.target, isNull);
      expect(seeks, isEmpty);
    });

    test('连续两个近目标样本后 settle,不再补 seek', () {
      var now = DateTime(2026, 1, 1);
      final seeks = <Duration>[];
      final coordinator = MoviePlayerStartupSeekCoordinator(
        seek: (position) async => seeks.add(position),
        isSurfaceReady: () => true,
        now: () => now,
      );

      coordinator.begin(const Duration(seconds: 60));
      expect(coordinator.target, const Duration(seconds: 60));

      coordinator.onPosition(const Duration(seconds: 59));
      coordinator.onPosition(const Duration(seconds: 60));

      now = now.add(const Duration(seconds: 2));
      coordinator.onPosition(Duration.zero);
      expect(seeks, isEmpty);
    });

    test('冷却期过后位置仍远离目标则补 seek,最多 maxRetries 次', () {
      var now = DateTime(2026, 1, 1);
      final seeks = <Duration>[];
      final coordinator = MoviePlayerStartupSeekCoordinator(
        seek: (position) async => seeks.add(position),
        isSurfaceReady: () => true,
        now: () => now,
      );
      const target = Duration(seconds: 60);

      coordinator.begin(target);
      coordinator.onPosition(Duration.zero);
      expect(seeks, isEmpty);

      now = now.add(const Duration(milliseconds: 900));
      coordinator.onPosition(Duration.zero);
      expect(seeks, [target]);

      now = now.add(const Duration(milliseconds: 900));
      coordinator.onPosition(Duration.zero);
      expect(seeks, [target, target]);

      now = now.add(const Duration(milliseconds: 900));
      coordinator.onPosition(Duration.zero);
      expect(seeks.length, 2);
    });

    test('窗口耗尽后放弃守卫', () {
      var now = DateTime(2026, 1, 1);
      final seeks = <Duration>[];
      final coordinator = MoviePlayerStartupSeekCoordinator(
        seek: (position) async => seeks.add(position),
        isSurfaceReady: () => true,
        now: () => now,
      );

      coordinator.begin(const Duration(seconds: 60));
      now = now.add(const Duration(milliseconds: 8100));
      coordinator.onPosition(Duration.zero);
      expect(seeks, isEmpty);

      now = now.add(const Duration(milliseconds: 900));
      coordinator.onPosition(Duration.zero);
      expect(seeks, isEmpty);
    });

    test('surface 未 ready 时探针挂起,不计样本也不重试', () {
      var now = DateTime(2026, 1, 1);
      var ready = false;
      final seeks = <Duration>[];
      final coordinator = MoviePlayerStartupSeekCoordinator(
        seek: (position) async => seeks.add(position),
        isSurfaceReady: () => ready,
        now: () => now,
      );
      const target = Duration(seconds: 60);

      coordinator.begin(target);
      now = now.add(const Duration(milliseconds: 900));
      coordinator.onPosition(Duration.zero);
      expect(seeks, isEmpty);

      ready = true;
      coordinator.onPosition(Duration.zero);
      expect(seeks, [target]);
    });
  });
}
