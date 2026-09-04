import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';
import 'package:sakuramedia/features/external_player/presentation/providers/external_player_preference_provider.dart';

/// 在用户已配置外部播放器时，解析地址并直接拉起它。
///
/// 返回 `false` 表示应继续原有的应用内播放流程：未配置、地址不可用或
/// 外部播放器无法拉起都会落在该分支。
Future<bool> tryLaunchConfiguredExternalPlayer(
  BuildContext context, {
  required Future<String?> Function() resolveUrl,
  required String title,
  int? positionMs,
}) async {
  const channel = ExternalPlayerChannel();
  if (!channel.isSupported) {
    return false;
  }

  try {
    final container = ProviderScope.containerOf(context, listen: false);
    final selection = await container.read(
      externalPlayerPreferenceProvider.future,
    );
    if (!selection.hasExternalPlayer) {
      return false;
    }

    final url = await resolveUrl();
    if (!context.mounted) {
      return true;
    }
    if (url == null || url.isEmpty) {
      return false;
    }

    final launched = await channel.launch(
      playerId: selection.playerId!,
      url: url,
      title: title,
      positionMs: positionMs,
    );
    if (!context.mounted || launched) {
      return true;
    }
    showToast('外部播放器不可用，已使用应用内播放');
  } on Object {
    // 无 ProviderScope、偏好读取或地址解析失败时，交给既有内置播放流程
    // 展示对应的错误状态。
  }
  return false;
}
