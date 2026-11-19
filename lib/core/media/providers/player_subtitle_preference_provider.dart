import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'player_subtitle_preference_provider.g.dart';

/// 字幕显示偏好：字号倍率 + 底部偏移（逻辑像素）。
@immutable
class PlayerSubtitlePreference {
  const PlayerSubtitlePreference({
    this.scale = 1.0,
    this.bottomOffset = 0.0,
  });

  static const double minScale = 0.75;
  static const double maxScale = 2.0;
  static const double minBottomOffset = 0.0;
  static const double maxBottomOffset = 240.0;

  final double scale;
  final double bottomOffset;

  bool get isDefault => scale == 1.0 && bottomOffset == 0.0;

  PlayerSubtitlePreference copyWith({double? scale, double? bottomOffset}) {
    return PlayerSubtitlePreference(
      scale: scale ?? this.scale,
      bottomOffset: bottomOffset ?? this.bottomOffset,
    );
  }
}

Duration? _noRetry(int retryCount, Object error) => null;

/// 设备级字幕偏好；与账号无关，所有播放器共用。
@Riverpod(keepAlive: true, retry: _noRetry)
class PlayerSubtitlePreferenceController
    extends _$PlayerSubtitlePreferenceController {
  static const String _scaleKey = 'player.subtitle.scale';
  static const String _bottomOffsetKey = 'player.subtitle.bottom_offset';

  @override
  Future<PlayerSubtitlePreference> build() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return PlayerSubtitlePreference(
        scale: (preferences.getDouble(_scaleKey) ?? 1.0)
            .clamp(
              PlayerSubtitlePreference.minScale,
              PlayerSubtitlePreference.maxScale,
            )
            .toDouble(),
        bottomOffset: (preferences.getDouble(_bottomOffsetKey) ?? 0.0)
            .clamp(
              PlayerSubtitlePreference.minBottomOffset,
              PlayerSubtitlePreference.maxBottomOffset,
            )
            .toDouble(),
      );
    } catch (_) {
      return const PlayerSubtitlePreference();
    }
  }

  Future<void> setScale(double value) async {
    final current = state.value ?? const PlayerSubtitlePreference();
    final scale = value
        .clamp(
          PlayerSubtitlePreference.minScale,
          PlayerSubtitlePreference.maxScale,
        )
        .toDouble();
    if (current.scale == scale) return;
    state = AsyncData(current.copyWith(scale: scale));
    await _persistDouble(_scaleKey, scale);
  }

  Future<void> setBottomOffset(double value) async {
    final current = state.value ?? const PlayerSubtitlePreference();
    final offset = value
        .clamp(
          PlayerSubtitlePreference.minBottomOffset,
          PlayerSubtitlePreference.maxBottomOffset,
        )
        .toDouble();
    if (current.bottomOffset == offset) return;
    state = AsyncData(current.copyWith(bottomOffset: offset));
    await _persistDouble(_bottomOffsetKey, offset);
  }

  Future<void> reset() async {
    state = const AsyncData(PlayerSubtitlePreference());
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_scaleKey);
      await preferences.remove(_bottomOffsetKey);
    } catch (_) {
      // 持久化失败保持内存态可用，下次启动回退到上次保存值。
    }
  }

  Future<void> _persistDouble(String key, double value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setDouble(key, value);
    } catch (_) {
      // 与外部播放器偏好一致：写盘失败不影响本次生效。
    }
  }
}
