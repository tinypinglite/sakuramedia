import 'dart:async';

import 'package:flutter/services.dart';

/// 订阅等二元状态切换的轻触感反馈。
///
/// iOS 走 `UISelectionFeedbackGenerator`，Android 走
/// `HapticFeedbackConstants.CLOCK_TICK`；无需权限，系统触感开关优先。
/// 桌面端与测试环境静默无副作用。fire-and-forget：触感不参与业务时序。
void triggerSelectionHaptic() {
  unawaited(
    HapticFeedback.selectionClick().catchError((Object _) {
      return;
    }),
  );
}
