import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_playback_rate_coordinator.dart';

void main() {
  group('MoviePlayerPlaybackRateCoordinator', () {
    late List<double> setRateCalls;
    late bool nextSetRateFails;
    late int notifyCount;

    MoviePlayerPlaybackRateCoordinator build({double initialRate = 1.0}) {
      setRateCalls = <double>[];
      nextSetRateFails = false;
      notifyCount = 0;
      final coord = MoviePlayerPlaybackRateCoordinator(
        setRate: (rate) async {
          setRateCalls.add(rate);
          if (nextSetRateFails) {
            nextSetRateFails = false;
            throw StateError('setRate fail');
          }
        },
        initialRate: initialRate,
      );
      coord.addListener(() => notifyCount++);
      return coord;
    }

    test('初始状态: currentRate = initialRate, 无 explicit, mobile display 同步', () {
      final coord = build(initialRate: 1.25);
      expect(coord.currentRate, 1.25);
      expect(coord.hasExplicitSelection, isFalse);
      expect(coord.mobileSpeedDisplay.value.rate, 1.25);
      expect(coord.mobileSpeedDisplay.value.hasExplicitSelection, isFalse);
      coord.dispose();
    });

    test('select 成功: 乐观置值 + setRate + 清 pending, 触发 notify', () async {
      final coord = build();
      await coord.select(1.5);

      expect(setRateCalls, [1.5]);
      expect(coord.currentRate, 1.5);
      expect(coord.hasExplicitSelection, isTrue);
      // 至少一次 notify(select 开头乐观置值)
      expect(notifyCount, greaterThanOrEqualTo(1));
      coord.dispose();
    });

    test('select 失败: 回滚 currentRate 与 hasExplicitSelection', () async {
      final coord = build(initialRate: 1.0);
      nextSetRateFails = true;
      await coord.select(2.0);

      expect(setRateCalls, [2.0]);
      expect(coord.currentRate, 1.0);
      expect(coord.hasExplicitSelection, isFalse);
      coord.dispose();
    });

    test('onRateStreamEvent: 与 pending 匹配 → 清 pending 并同步 current', () async {
      final coord = build(initialRate: 1.0);
      // 触发 pending: select 前设 pending, setRate 后立即清空——
      // 用一个更可控的时序: 手工制造 pending 场景
      final future = coord.select(1.5);
      // 此刻 pending=1.5, currentRate 已乐观置为 1.5
      coord.onRateStreamEvent(1.5); // 匹配 → 清 pending
      await future;
      expect(coord.currentRate, 1.5);
      coord.dispose();
    });

    test('onRateStreamEvent: 与 pending 不匹配 → 忽略, 保留 pending', () async {
      final coord = build(initialRate: 1.0);
      final future = coord.select(2.0);
      // 冒出一个不匹配的自然事件(比如 1.0)——应被忽略, 不覆盖 current
      coord.onRateStreamEvent(1.0);
      expect(coord.currentRate, 2.0); // 保持选中值
      await future;
      coord.dispose();
    });

    test('onRateStreamEvent: 无 pending 且与 current 相差 ≥0.001 → 同步 + notify', () {
      final coord = build(initialRate: 1.0);
      final before = notifyCount;
      coord.onRateStreamEvent(1.5);
      expect(coord.currentRate, 1.5);
      expect(coord.mobileSpeedDisplay.value.rate, 1.5);
      expect(notifyCount, greaterThan(before));
      coord.dispose();
    });

    test('onRateStreamEvent: 与 current 相差 <0.001 → 幂等, 不 notify', () {
      final coord = build(initialRate: 1.0);
      final before = notifyCount;
      coord.onRateStreamEvent(1.0);
      expect(notifyCount, before);
      coord.dispose();
    });

    test('selectFromMobile: mobile display 立即乐观置到目标档', () async {
      final coord = build();
      final future = coord.selectFromMobile(2.0);
      // 微任务后 mobile display 应该已在目标值(hasExplicit=true)
      expect(coord.mobileSpeedDisplay.value.rate, 2.0);
      expect(coord.mobileSpeedDisplay.value.hasExplicitSelection, isTrue);
      await future;
      // 完成后仍保持目标值
      expect(coord.mobileSpeedDisplay.value.rate, 2.0);
      expect(coord.mobileSpeedDisplay.value.hasExplicitSelection, isTrue);
      coord.dispose();
    });

    test('resetMobileDisplayForNewMedia: mobile display 复位到新初始速率, 清 hasExplicit', () async {
      final coord = build(initialRate: 1.0);
      // 只有移动端路径会同步更新 mobile display 的 hasExplicit
      // (桌面 select 不触摸 mobile display, 保留历史解耦)
      await coord.selectFromMobile(1.5);
      expect(coord.mobileSpeedDisplay.value.hasExplicitSelection, isTrue);

      coord.resetMobileDisplayForNewMedia(1.0);
      expect(coord.mobileSpeedDisplay.value.rate, 1.0);
      expect(coord.mobileSpeedDisplay.value.hasExplicitSelection, isFalse);
      // 权威 currentRate/hasExplicit 不受 resetMobileDisplayForNewMedia 影响
      // (换片后 player.stream.rate 会自然喂新值)
      coord.dispose();
    });
  });
}
