import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 自适应玻璃档位存储；生产使用 SharedPreferences，测试/预览使用内存实现。
abstract class GlassQualityStore {
  GlassQuality? read();
  Future<void> save(GlassQuality quality);
}

class SharedPreferencesGlassQualityStore implements GlassQualityStore {
  SharedPreferencesGlassQualityStore(this._preferences);

  static const String qualityKey = 'app.glass_quality';

  final SharedPreferences _preferences;

  static Future<GlassQualityStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesGlassQualityStore(preferences);
  }

  @override
  GlassQuality? read() {
    final name = _preferences.getString(qualityKey);
    if (name == null) {
      return null;
    }
    for (final quality in GlassQuality.values) {
      if (quality.name == name) {
        return quality;
      }
    }
    return null;
  }

  @override
  Future<void> save(GlassQuality quality) async {
    try {
      await _preferences.setString(qualityKey, quality.name);
    } catch (_) {
      // 持久化失败不阻塞自适应；下次启动重新预热。
    }
  }
}

class InMemoryGlassQualityStore implements GlassQualityStore {
  InMemoryGlassQualityStore([this._quality]);

  GlassQuality? _quality;

  @override
  GlassQuality? read() => _quality;

  @override
  Future<void> save(GlassQuality quality) async {
    _quality = quality;
  }
}
