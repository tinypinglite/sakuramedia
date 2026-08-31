import 'package:flutter/foundation.dart';

/// 「默认外部播放器」偏好的值对象(仅 Android 使用)。
///
/// 未选择任何外部播放器([hasExternalPlayer] 为 false)时表示使用应用内
/// 播放器。持久化读写在 `externalPlayerPreferenceProvider`。
@immutable
class ExternalPlayerSelection {
  const ExternalPlayerSelection({this.packageName, this.label});

  /// 选定播放器的包名；为空表示使用应用内播放器。
  final String? packageName;

  /// 选定播放器的显示名称。
  final String? label;

  bool get hasExternalPlayer => packageName != null && packageName!.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExternalPlayerSelection &&
        other.packageName == packageName &&
        other.label == label;
  }

  @override
  int get hashCode => Object.hash(packageName, label);
}
