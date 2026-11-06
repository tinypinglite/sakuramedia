import 'package:flutter/foundation.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_quality.dart';

/// 玻璃自适应质量的全局配置。
///
/// 运行时只挂一个根部 `GlassAdaptiveScope`；要整体关闭自适应或调整阈值，
/// 只改本文件。
abstract final class AppGlassPerformance {
  /// 一键关闭自适应，回到各组件自己的质量意图。
  static const bool enabled = true;

  /// 帧耗时预算；当前按 60Hz 的 16ms 设定。
  static const int targetFrameMs = 16;

  /// 预热阶段 P75 低于该值视为能跑 premium。
  static const double warmupPremiumThresholdMs = 20;

  /// 预热阶段 P75 低于该值视为能跑 standard，否则降到 minimal。
  static const double warmupStandardThresholdMs = 28;

  /// 允许在持续低负载后升档，避免一次瞬时卡顿永久锁在低档。
  static const bool allowStepUp = true;

  /// 首版关闭 frostStep：1.16.1 没有恢复 frost 状态的入口，开启后持久化
  /// 档位会和实际渲染档位不一致。
  static const bool frostStep = false;

  static GlassAdaptiveScopeConfig adaptiveConfig({
    required GlassQuality? initialQuality,
    required void Function(GlassQuality) onQualityChanged,
  }) {
    return GlassAdaptiveScopeConfig(
      initialQuality: initialQuality,
      minQuality: AppGlassQuality.minimum,
      maxQuality: AppGlassQuality.maximum,
      targetFrameMs: targetFrameMs,
      allowStepUp: allowStepUp,
      warmupPremiumThresholdMs: warmupPremiumThresholdMs,
      warmupStandardThresholdMs: warmupStandardThresholdMs,
      frostStep: frostStep,
      onDiagnostic: (diagnostic) {
        // 预热完成但质量没变化时不会触发 onQualityChanged；用 onDiagnostic
        // 才能把快设备的 premium 结果也持久化下来。
        onQualityChanged(diagnostic.to);
        if (kDebugMode || kProfileMode) {
          debugPrint('[glass] $diagnostic');
        }
      },
    );
  }
}
