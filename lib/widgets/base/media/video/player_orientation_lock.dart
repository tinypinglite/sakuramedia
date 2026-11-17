import 'package:flutter/foundation.dart';
import 'package:sakuramedia/widgets/base/media/video/player_screen_orientation.dart';

/// 移动端播放页的方向锁状态（页面级 View 状态）。
///
/// 默认锁定横屏；[toggle] 在「锁定横屏」和「跟随系统方向」之间切换并立即
/// 应用系统方向。退出页面时由页面恢复系统方向，本对象只记录当前选择。
class PlayerOrientationLock extends ChangeNotifier {
  PlayerOrientationLock({bool locked = true}) : _locked = locked;

  bool _locked;
  bool get isLocked => _locked;

  Future<void> toggle() async {
    _locked = !_locked;
    notifyListeners();
    await applyPlayerOrientationLock(locked: _locked);
  }
}
