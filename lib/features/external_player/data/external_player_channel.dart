import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sakuramedia/features/external_player/data/external_player_app.dart';

/// 与原生（仅 Android）交互的外部播放器通道：枚举可用播放器、显式拉起播放。
///
/// 非 Android / Web 平台上 [isSupported] 为 false，所有方法安全降级（不抛出）。
class ExternalPlayerChannel {
  const ExternalPlayerChannel();

  static const MethodChannel _channel = MethodChannel(
    'sakuramedia/external_player',
  );

  /// 仅 Android 原生实现该通道。
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 列出系统中可播放视频的应用。
  ///
  /// [sampleUrl] 传入与实际播放同源的直链（通常是服务器 baseUrl），
  /// 以保证枚举到的播放器确实能接住该协议/类型的视频。
  Future<List<ExternalPlayerApp>> listPlayers({String? sampleUrl}) async {
    if (!isSupported) {
      return const <ExternalPlayerApp>[];
    }
    try {
      final raw = await _channel.invokeListMethod<dynamic>('listPlayers', {
        'sampleUrl': sampleUrl,
      });
      if (raw == null) {
        return const <ExternalPlayerApp>[];
      }
      final players = <ExternalPlayerApp>[];
      for (final item in raw) {
        if (item is Map) {
          final player = ExternalPlayerApp.fromMap(item.cast<Object?, Object?>());
          if (player != null) {
            players.add(player);
          }
        }
      }
      players.sort(
        (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      );
      return players;
    } on PlatformException {
      return const <ExternalPlayerApp>[];
    } on MissingPluginException {
      return const <ExternalPlayerApp>[];
    }
  }

  /// 显式拉起指定播放器播放 [url]。
  ///
  /// 返回 true 表示已成功唤起；false 表示目标播放器不可用（例如已卸载），
  /// 调用方应据此回落到应用内播放并提示用户。
  Future<bool> launch({
    required String packageName,
    required String url,
    String? title,
    int? positionMs,
  }) async {
    if (!isSupported) {
      return false;
    }
    try {
      final launched = await _channel.invokeMethod<bool>('launch', {
        'packageName': packageName,
        'url': url,
        'title': title,
        'positionMs': positionMs,
      });
      return launched ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
