import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 持久化“默认外部播放器”偏好（仅 Android 使用）。
///
/// 未选择任何外部播放器（[hasExternalPlayer] 为 false）时表示使用应用内播放器。
class ExternalPlayerStore extends ChangeNotifier {
  ExternalPlayerStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _packageKey = 'android.external_player.package_name';
  static const String _labelKey = 'android.external_player.label';

  SharedPreferences? _preferences;
  String? _packageName;
  String? _label;
  bool _isLoaded = false;

  /// 选定播放器的包名；为空表示使用应用内播放器。
  String? get packageName => _packageName;

  /// 选定播放器的显示名称。
  String? get label => _label;

  bool get isLoaded => _isLoaded;

  bool get hasExternalPlayer =>
      _packageName != null && _packageName!.isNotEmpty;

  Future<void> load() async {
    try {
      final preferences = _preferences ??= await SharedPreferences.getInstance();
      final storedPackage = preferences.getString(_packageKey);
      _packageName =
          storedPackage != null && storedPackage.isNotEmpty
              ? storedPackage
              : null;
      _label = _packageName == null ? null : preferences.getString(_labelKey);
    } catch (_) {
      _packageName = null;
      _label = null;
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> selectExternalPlayer({
    required String packageName,
    required String label,
  }) async {
    if (_packageName == packageName && _label == label) {
      return;
    }
    _packageName = packageName;
    _label = label;
    notifyListeners();
    try {
      final preferences = _preferences ??= await SharedPreferences.getInstance();
      await preferences.setString(_packageKey, packageName);
      await preferences.setString(_labelKey, label);
    } catch (_) {
      // 忽略持久化失败，保持内存态可用。
    }
  }

  Future<void> useInAppPlayer() async {
    if (!hasExternalPlayer) {
      return;
    }
    _packageName = null;
    _label = null;
    notifyListeners();
    try {
      final preferences = _preferences ??= await SharedPreferences.getInstance();
      await preferences.remove(_packageKey);
      await preferences.remove(_labelKey);
    } catch (_) {
      // 忽略持久化失败，保持内存态可用。
    }
  }
}
