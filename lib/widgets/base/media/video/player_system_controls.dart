import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

/// 移动播放器左右分侧手势使用的系统亮度与媒体音量控制。
///
/// `media_kit` 的手势回调传入 0.0–1.0 的绝对值，因此初始值必须在控制层首次
/// 挂载前读取，否则第一次滑动会从默认的 50% 突然跳变。写入失败只记录日志，
/// 不打断播放；亮度只在当前播放面退出时恢复，音量保持系统设置。
class PlayerSystemControls {
  PlayerSystemControls({
    double initialBrightness = 0.5,
    double initialVolume = 0.5,
  }) : _initialBrightness = _clampLevel(initialBrightness),
       _initialVolume = _clampLevel(initialVolume);

  double _initialBrightness;
  double _initialVolume;
  bool _brightnessChanged = false;
  Future<void>? _initialization;
  Future<void> _brightnessWrites = Future<void>.value();
  Future<void> _volumeWrites = Future<void>.value();

  double get initialBrightness => _initialBrightness;

  double get initialVolume => _initialVolume;

  Future<void> initialize() {
    return _initialization ??= _readInitialLevels();
  }

  void setBrightness(double value) {
    final level = _clampLevel(value);
    _initialBrightness = level;
    _brightnessChanged = true;
    _brightnessWrites = _brightnessWrites.then((_) => _writeBrightness(level));
  }

  void setVolume(double value) {
    final level = _clampLevel(value);
    _initialVolume = level;
    _volumeWrites = _volumeWrites.then((_) => _writeVolume(level));
  }

  Future<void> resetBrightness() async {
    if (!_brightnessChanged) {
      return;
    }
    _brightnessChanged = false;
    await _brightnessWrites;
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
      _initialBrightness = _clampLevel(
        await ScreenBrightness.instance.application,
      );
    } catch (error) {
      _initialBrightness = 0.5;
      debugPrint('[player-system-controls] reset brightness failed: $error');
    }
  }

  Future<void> _readInitialLevels() async {
    VolumeController.instance.showSystemUI = false;
    final levels = await Future.wait<double?>([
      _readBrightness(),
      _readVolume(),
    ]);
    final brightness = levels[0];
    final volume = levels[1];
    if (brightness != null) {
      _initialBrightness = brightness;
    }
    if (volume != null) {
      _initialVolume = volume;
    }
  }

  Future<double?> _readBrightness() async {
    try {
      return _clampLevel(
        await ScreenBrightness.instance.application.timeout(_readTimeout),
      );
    } catch (error) {
      debugPrint('[player-system-controls] read brightness failed: $error');
      return null;
    }
  }

  Future<double?> _readVolume() async {
    try {
      return _clampLevel(
        await VolumeController.instance.getVolume().timeout(_readTimeout),
      );
    } catch (error) {
      debugPrint('[player-system-controls] read volume failed: $error');
      return null;
    }
  }

  Future<void> _writeBrightness(double value) async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(value);
    } catch (error) {
      debugPrint('[player-system-controls] write brightness failed: $error');
    }
  }

  Future<void> _writeVolume(double value) async {
    try {
      VolumeController.instance.showSystemUI = false;
      await VolumeController.instance.setVolume(value);
    } catch (error) {
      debugPrint('[player-system-controls] write volume failed: $error');
    }
  }

  static double _clampLevel(double value) => value.clamp(0.0, 1.0).toDouble();

  static const Duration _readTimeout = Duration(milliseconds: 300);
}
