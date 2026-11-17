import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/cast/data/cast_device.dart';
import 'package:sakuramedia/features/cast/data/cast_director.dart';
import 'package:upnp_client/upnp_client.dart';

/// 一次播放位置查询的结果。
class CastPositionInfo {
  const CastPositionInfo({required this.position, this.duration});

  final Duration position;

  /// 电视上报的总时长；设备不支持时可能为 null，由本地影片数据兜底。
  final Duration? duration;
}

/// 电视的传输状态（对应 DLNA 的 CurrentTransportState）。
enum CastPlaybackStatus { playing, paused, stopped, transitioning, unknown }

/// 投屏设备的控制接口；抽成窄接口便于单元测试注入假实现。
abstract class CastTransport {
  Future<CastPositionInfo> positionInfo();

  Future<CastPlaybackStatus> playbackStatus();

  Future<void> seek(Duration target);

  Future<void> play();

  Future<void> pause();

  Future<void> stop();
}

/// 单个 SOAP 动作的默认超时。
///
/// upnp_client 内部固定 30 秒超时，遥控轮询场景必须收紧，否则电视离线时
/// 请求会一直堆积。
const Duration kCastActionTimeout = Duration(seconds: 4);

/// 基于 upnp_client AVTransport 的实现。
class UpnpCastTransport implements CastTransport {
  UpnpCastTransport(
    CastDevice device, {
    this._actionTimeout = kCastActionTimeout,
  }) : _transport = _resolveAvTransport(device);

  final AvTransportService _transport;
  final Duration _actionTimeout;

  static AvTransportService _resolveAvTransport(CastDevice device) {
    final transport = device.renderer.avTransport;
    if (transport == null) {
      throw const CastException(CastErrorCode.deviceCannotPlayVideo);
    }
    return transport;
  }

  @override
  Future<CastPositionInfo> positionInfo() async {
    final info = await _transport.getPositionInfo().timeout(_actionTimeout);
    return CastPositionInfo(
      position: parseUpnpTime(info.relTime) ?? Duration.zero,
      duration: parseUpnpTime(info.trackDuration),
    );
  }

  @override
  Future<CastPlaybackStatus> playbackStatus() async {
    final info = await _transport.getTransportInfo().timeout(_actionTimeout);
    return switch (info.currentTransportState) {
      TransportState.playing => CastPlaybackStatus.playing,
      TransportState.pausedPlayback => CastPlaybackStatus.paused,
      TransportState.stopped => CastPlaybackStatus.stopped,
      TransportState.transitioning => CastPlaybackStatus.transitioning,
      _ => CastPlaybackStatus.unknown,
    };
  }

  @override
  Future<void> seek(Duration target) => _transport
      .seek(SeekMode.relTime, formatUpnpTime(target))
      .timeout(_actionTimeout);

  @override
  Future<void> play() => _transport.play().timeout(_actionTimeout);

  @override
  Future<void> pause() => _transport.pause().timeout(_actionTimeout);

  @override
  Future<void> stop() => _transport.stop().timeout(_actionTimeout);
}

final RegExp _upnpTimePattern = RegExp(r'^(\d+):(\d{1,2}):(\d{1,2})(?:\.(\d+))?$');

/// 解析 DLNA 时间字符串（`HH:MM:SS`，可带小数秒）；无效值返回 null。
@visibleForTesting
Duration? parseUpnpTime(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  final match = _upnpTimePattern.firstMatch(trimmed);
  if (match == null) {
    return null;
  }
  final hours = int.tryParse(match.group(1)!);
  final minutes = int.tryParse(match.group(2)!);
  final seconds = int.tryParse(match.group(3)!);
  if (hours == null || minutes == null || seconds == null) {
    return null;
  }
  final fraction = match.group(4) ?? '';
  final milliseconds = fraction.isEmpty
      ? 0
      : int.tryParse(fraction.padRight(3, '0').substring(0, 3)) ?? 0;
  return Duration(
    hours: hours,
    minutes: minutes,
    seconds: seconds,
    milliseconds: milliseconds,
  );
}

/// 生成 DLNA Seek 目标时间（`HH:MM:SS`），负值按 0 处理。
@visibleForTesting
String formatUpnpTime(Duration duration) {
  final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${pad(hours)}:${pad(minutes)}:${pad(seconds)}';
}
