import 'package:flutter/foundation.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_mobile_drawers.dart';

/// 移动端底部抽屉与右侧「视频信息」侧抽屉的三态状态机
/// （从 `_MoviePlayerSurfaceState` 抽出的引擎件）。
///
/// 语义：
/// - [activeDrawer] 记录当前打开的底部抽屉（speed / subtitle / null）。
/// - [isInfoSideOpen] 记录右侧「视频信息」侧抽屉是否打开。
/// - 两类抽屉互斥：打开任一侧会关闭另一侧。
/// - 全部方法幂等：已处于目标态不 notify。
///
/// 状态变化经 [ChangeNotifier] 通知，宿主 State 监听后 setState。
/// 「打开 info side 前需刷新 native stats」这类异步编排留在宿主，
/// coordinator 只管纯状态。
class MoviePlayerMobileDrawerCoordinator extends ChangeNotifier {
  MoviePlayerMobileDrawerType? _activeDrawer;
  bool _isInfoSideOpen = false;

  MoviePlayerMobileDrawerType? get activeDrawer => _activeDrawer;
  bool get isInfoSideOpen => _isInfoSideOpen;

  /// 切换底部抽屉：同类型重复点 → 关闭；info side 若开着会一并关闭。
  void toggle(MoviePlayerMobileDrawerType type) {
    final next = _activeDrawer == type ? null : type;
    if (next == _activeDrawer && !_isInfoSideOpen) {
      return;
    }
    _activeDrawer = next;
    _isInfoSideOpen = false;
    notifyListeners();
  }

  /// 关闭当前底部抽屉（幂等）。
  void closeDrawer() {
    if (_activeDrawer == null) {
      return;
    }
    _activeDrawer = null;
    notifyListeners();
  }

  /// 打开 info side 侧抽屉（幂等）；底部抽屉若开着会一并关闭。
  /// 宿主决定何时调用（通常先 `await statsSampler.refreshNative()`）。
  void openInfoSide() {
    if (_isInfoSideOpen && _activeDrawer == null) {
      return;
    }
    _isInfoSideOpen = true;
    _activeDrawer = null;
    notifyListeners();
  }

  /// 关闭 info side 侧抽屉（幂等）。
  void dismissInfoSide() {
    if (!_isInfoSideOpen) {
      return;
    }
    _isInfoSideOpen = false;
    notifyListeners();
  }

  /// 复位所有抽屉（换片 / 播放失败 / touch controls 关闭时用）。
  /// 幂等：全都是关态不 notify。
  void closeAll() {
    if (_activeDrawer == null && !_isInfoSideOpen) {
      return;
    }
    _activeDrawer = null;
    _isInfoSideOpen = false;
    notifyListeners();
  }
}
