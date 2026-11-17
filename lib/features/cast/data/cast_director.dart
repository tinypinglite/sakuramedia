import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/cast/data/cast_device.dart';
import 'package:sakuramedia/features/cast/data/cast_didl.dart';
import 'package:sakuramedia/features/cast/data/multicast_lock_channel.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';
import 'package:upnp_client/upnp_client.dart';

/// 当前平台是否支持投屏（iOS 受系统组播限制，暂不提供设备发现）。
bool get isCastPlatformSupported => switch (defaultTargetPlatform) {
  TargetPlatform.android ||
  TargetPlatform.macOS ||
  TargetPlatform.windows => true,
  _ => false,
};

/// 投屏过程中的业务错误类型；面向用户的文案由 [castErrorMessage] 按当前语言生成。
enum CastErrorCode {
  /// 设备没有 AVTransport，无法播放视频。
  deviceCannotPlayVideo,
}

/// 投屏流程中的业务错误，[code] 决定面向用户的原因。
class CastException implements Exception {
  const CastException(this.code);

  final CastErrorCode code;

  @override
  String toString() => 'CastException: ${code.name}';
}

/// DLNA 投屏：局域网设备发现 + 播放地址推送。
class CastDirector {
  const CastDirector({AppLocalizations Function()? l10n}) : _l10n = l10n;

  final AppLocalizations Function()? _l10n;

  AppLocalizations get _localizations => _l10n?.call() ?? AppLocalizationsZh();

  final MulticastLockChannel _multicastLock = const MulticastLockChannel();

  /// 单轮发现的等待窗口：电视的 SSDP 响应通常在 1-3 秒内到达。
  static const Duration _discoveryWindow = Duration(seconds: 5);

  /// 发现可投屏设备。
  ///
  /// 结果流式产出（设备逐个可用），窗口结束自动关闭；取消订阅会同步
  /// 停止扫描并释放组播锁。
  Stream<CastDevice> discover() {
    final controller = StreamController<CastDevice>();
    final seen = <String>{};
    DeviceDiscoverer? discoverer;
    StreamSubscription<Device>? subscription;
    var lockAcquired = false;
    var cleanedUp = false;

    Future<void> cleanUp() async {
      if (cleanedUp) {
        return;
      }
      cleanedUp = true;
      await subscription?.cancel();
      discoverer?.dispose();
      if (lockAcquired) {
        lockAcquired = false;
        await _multicastLock.release();
      }
      if (!controller.isClosed) {
        await controller.close();
      }
    }

    Future<void> run() async {
      try {
        lockAcquired = await _multicastLock.acquire();
        final localDiscoverer = DeviceDiscoverer();
        discoverer = localDiscoverer;
        subscription = localDiscoverer.devices.listen((device) {
          final castDevice = castDeviceFromRenderer(device, l10n: _localizations);
          if (castDevice != null && seen.add(castDevice.id)) {
            if (!controller.isClosed) {
              controller.add(castDevice);
            }
          }
        });
        await localDiscoverer.start(
          addressTypes: const [InternetAddressType.IPv4],
        );
        // getDevices 负责发出 M-SEARCH；设备响应由上面的监听流式转发，
        // 这里只等窗口结束，不使用其返回值。
        unawaited(
          localDiscoverer.getDevices(
            timeout: _discoveryWindow,
            searchTarget: UpnpDeviceType.mediaRenderer.urn(),
          ),
        );
        await Future<void>.delayed(
          _discoveryWindow + const Duration(milliseconds: 500),
        );
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        await cleanUp();
      }
    }

    controller.onCancel = cleanUp;
    unawaited(run());
    return controller.stream;
  }

  /// 把媒体地址推给设备开始播放。
  Future<void> cast({
    required CastDevice device,
    required String url,
    required String title,
    String? contentType,
  }) async {
    final transport = device.renderer.avTransport;
    if (transport == null) {
      throw const CastException(CastErrorCode.deviceCannotPlayVideo);
    }
    await transport.setAVTransportURI(
      url,
      metadata: buildVideoDidl(
        url: url,
        title: title,
        contentType: contentType,
      ),
    );
    await transport.play();
  }
}

/// 把 upnp_client 设备映射为投屏设备；非媒体渲染器或不带 AVTransport 时返回 null。
@visibleForTesting
CastDevice? castDeviceFromRenderer(
  Device device, {
  required AppLocalizations l10n,
}) {
  if (device is! MediaRenderer || device.avTransport == null) {
    return null;
  }
  final location = device.url;
  if (location == null || location.isEmpty) {
    return null;
  }
  final friendlyName = device.description?.friendlyName?.trim() ?? '';
  final host = Uri.tryParse(location)?.host ?? '';
  return CastDevice(
    id: device.description?.uuid ?? location,
    name: friendlyName.isEmpty ? l10n.castUnnamedDevice : friendlyName,
    address: host.isEmpty ? location : host,
    renderer: device,
  );
}

/// 将投屏过程中的异常映射为用户可读文案。
///
/// [fallback] 是调用点自己的兜底文案（如「跳转失败」）；不传时用通用的
/// 「投屏失败，请重试」。
String castErrorMessage(
  Object error, {
  required AppLocalizations l10n,
  String? fallback,
}) {
  final resolvedFallback = fallback ?? l10n.castErrorFallback;
  if (error is CastException) {
    return switch (error.code) {
      CastErrorCode.deviceCannotPlayVideo => l10n.castDeviceCannotPlayVideo,
    };
  }
  if (error is UPnPException) {
    return switch (error.errorCode) {
      701 => l10n.castTvCannotStartPlayback,
      704 => l10n.castTvUnsupportedFormat,
      715 || 716 => l10n.castTvCannotAccessUrl,
      _ => resolvedFallback,
    };
  }
  if (error is TimeoutException) {
    return l10n.castTvNotResponding;
  }
  if (error is SocketException) {
    return l10n.castTvConnectionFailed;
  }
  return resolvedFallback;
}
