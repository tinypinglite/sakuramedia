import 'package:upnp_client/upnp_client.dart';

/// 局域网内可投屏的 DLNA 媒体渲染设备（电视 / 投屏盒子）。
class CastDevice {
  const CastDevice({
    required this.id,
    required this.name,
    required this.address,
    required this.renderer,
  });

  /// 设备稳定标识（优先 UDN，缺失时退化为定位地址）。
  final String id;

  /// 设备显示名（friendlyName）。
  final String name;

  /// 设备主机地址，用于界面展示。
  final String address;

  /// upnp_client 的媒体渲染器句柄，用于下发播放指令。
  final MediaRenderer renderer;
}
