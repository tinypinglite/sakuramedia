import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android 组播锁通道。
///
/// 部分设备的 WiFi 芯片默认过滤组播帧，不持有 MulticastLock 时会收不到
/// SSDP 设备响应；其他平台没有该限制，安全降级为 no-op。
class MulticastLockChannel {
  const MulticastLockChannel();

  static const MethodChannel _channel = MethodChannel(
    'sakuramedia/multicast_lock',
  );

  bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  /// 尝试获取锁；返回是否实际持有。不支持或失败时返回 false，不抛出。
  Future<bool> acquire() async {
    if (!isSupported) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('acquire') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 释放锁；未持有时调用同样安全。
  Future<void> release() async {
    if (!isSupported) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('release');
    } on PlatformException {
      // 释放失败不影响后续流程。
    } on MissingPluginException {
      // 防御性忽略：桌面端不会走到这里。
    }
  }
}
