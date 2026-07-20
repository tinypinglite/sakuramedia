import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_mobile_drawer_coordinator.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_mobile_drawers.dart';

void main() {
  group('MoviePlayerMobileDrawerCoordinator', () {
    late MoviePlayerMobileDrawerCoordinator coord;
    late int notifyCount;

    setUp(() {
      coord = MoviePlayerMobileDrawerCoordinator();
      notifyCount = 0;
      coord.addListener(() => notifyCount++);
    });

    tearDown(() {
      coord.dispose();
    });

    test('初始状态: 无 activeDrawer, info side 未开', () {
      expect(coord.activeDrawer, isNull);
      expect(coord.isInfoSideOpen, isFalse);
    });

    test('toggle 打开新抽屉 → 触发 notify', () {
      coord.toggle(MoviePlayerMobileDrawerType.speed);
      expect(coord.activeDrawer, MoviePlayerMobileDrawerType.speed);
      expect(notifyCount, 1);
    });

    test('toggle 同类型二次点击 → 关闭并 notify', () {
      coord.toggle(MoviePlayerMobileDrawerType.speed);
      coord.toggle(MoviePlayerMobileDrawerType.speed);
      expect(coord.activeDrawer, isNull);
      expect(notifyCount, 2);
    });

    test('toggle 不同类型 → 切换到新类型', () {
      coord.toggle(MoviePlayerMobileDrawerType.speed);
      coord.toggle(MoviePlayerMobileDrawerType.subtitle);
      expect(coord.activeDrawer, MoviePlayerMobileDrawerType.subtitle);
      expect(notifyCount, 2);
    });

    test('toggle 时若 info side 开着 → 一并关闭', () {
      coord.openInfoSide();
      notifyCount = 0;
      coord.toggle(MoviePlayerMobileDrawerType.speed);
      expect(coord.activeDrawer, MoviePlayerMobileDrawerType.speed);
      expect(coord.isInfoSideOpen, isFalse);
      expect(notifyCount, 1);
    });

    test('closeDrawer 幂等: 已关不 notify', () {
      coord.closeDrawer();
      expect(notifyCount, 0);
      coord.toggle(MoviePlayerMobileDrawerType.speed);
      coord.closeDrawer();
      expect(coord.activeDrawer, isNull);
      expect(notifyCount, 2);
      coord.closeDrawer();
      expect(notifyCount, 2);
    });

    test('openInfoSide 打开并 notify', () {
      coord.openInfoSide();
      expect(coord.isInfoSideOpen, isTrue);
      expect(notifyCount, 1);
    });

    test('openInfoSide 时若底部抽屉开着 → 一并关闭', () {
      coord.toggle(MoviePlayerMobileDrawerType.speed);
      notifyCount = 0;
      coord.openInfoSide();
      expect(coord.isInfoSideOpen, isTrue);
      expect(coord.activeDrawer, isNull);
      expect(notifyCount, 1);
    });

    test('openInfoSide 幂等: 已开且无底部抽屉时不 notify', () {
      coord.openInfoSide();
      notifyCount = 0;
      coord.openInfoSide();
      expect(notifyCount, 0);
    });

    test('dismissInfoSide 幂等: 已关不 notify', () {
      coord.dismissInfoSide();
      expect(notifyCount, 0);
      coord.openInfoSide();
      coord.dismissInfoSide();
      expect(coord.isInfoSideOpen, isFalse);
      expect(notifyCount, 2);
      coord.dismissInfoSide();
      expect(notifyCount, 2);
    });

    test('closeAll: 有开着的 → 全关 + 一次 notify', () {
      coord.toggle(MoviePlayerMobileDrawerType.speed);
      notifyCount = 0;
      coord.closeAll();
      expect(coord.activeDrawer, isNull);
      expect(coord.isInfoSideOpen, isFalse);
      expect(notifyCount, 1);
    });

    test('closeAll: 已全关 → 幂等不 notify', () {
      coord.closeAll();
      expect(notifyCount, 0);
    });
  });
}
