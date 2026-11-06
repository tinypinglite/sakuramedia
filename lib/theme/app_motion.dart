import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

/// 应用内 UI 过渡的统一节奏。
///
/// 只约束界面动画（淡入、展开、切换）；播放器进度、Cast 进度、
/// 下载/任务轮询等真实时间语义不要使用这里的时长。
@immutable
class AppMotion extends ThemeExtension<AppMotion> {
  const AppMotion({
    this.fast = const Duration(milliseconds: 120),
    this.normal = const Duration(milliseconds: 180),
    this.slow = const Duration(milliseconds: 250),
    this.slower = const Duration(milliseconds: 320),
    this.standard = Curves.easeOutCubic,
  });

  const AppMotion.defaults() : this();

  /// 小范围反馈：hover、勾选、颜色切换。
  final Duration fast;

  /// 常规显隐与淡入淡出。
  final Duration normal;

  /// 面板/抽屉展开。
  final Duration slow;

  /// 跨页面或较大区域的过渡。
  final Duration slower;

  /// 默认缓动。
  final Curve standard;

  @override
  AppMotion copyWith({
    Duration? fast,
    Duration? normal,
    Duration? slow,
    Duration? slower,
    Curve? standard,
  }) {
    return AppMotion(
      fast: fast ?? this.fast,
      normal: normal ?? this.normal,
      slow: slow ?? this.slow,
      slower: slower ?? this.slower,
      standard: standard ?? this.standard,
    );
  }

  @override
  AppMotion lerp(ThemeExtension<AppMotion>? other, double t) {
    if (other is! AppMotion) {
      return this;
    }
    return AppMotion(
      fast: _lerpDuration(fast, other.fast, t),
      normal: _lerpDuration(normal, other.normal, t),
      slow: _lerpDuration(slow, other.slow, t),
      slower: _lerpDuration(slower, other.slower, t),
      standard: t < 0.5 ? standard : other.standard,
    );
  }

  static Duration _lerpDuration(Duration a, Duration b, double t) {
    return Duration(
      microseconds: lerpDouble(a.inMicroseconds, b.inMicroseconds, t)!.round(),
    );
  }
}

extension AppMotionThemeDataX on ThemeData {
  AppMotion get appMotion => extension<AppMotion>() ?? const AppMotion();
}

extension AppMotionBuildContextX on BuildContext {
  AppMotion get appMotion => Theme.of(this).appMotion;
}
