import 'package:flutter/foundation.dart';

/// 「默认外部播放器」偏好的值对象。
///
/// 未选择任何外部播放器([hasExternalPlayer] 为 false)时表示使用应用内
/// 播放器。持久化读写在 `externalPlayerPreferenceProvider`。
@immutable
class ExternalPlayerSelection {
  const ExternalPlayerSelection({this.playerId, this.label});

  /// 选定播放器的平台标识；为空表示使用应用内播放器。
  final String? playerId;

  /// 选定播放器的显示名称。
  final String? label;

  bool get hasExternalPlayer => playerId != null && playerId!.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExternalPlayerSelection &&
        other.playerId == playerId &&
        other.label == label;
  }

  @override
  int get hashCode => Object.hash(playerId, label);
}
