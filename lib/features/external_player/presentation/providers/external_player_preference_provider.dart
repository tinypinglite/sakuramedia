import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/external_player/data/external_player_selection.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'external_player_preference_provider.g.dart';

/// 「默认外部播放器」偏好(仅 Android 使用,keepAlive AsyncNotifier)。
///
/// 迁移前形态:`ExternalPlayerStore extends ChangeNotifier` + legacy
/// `ChangeNotifierProvider` 的 `..load()` 副作用——现由 `build()` 承载读盘,
/// `isLoaded` 字段由 [AsyncValue] 的加载态取代。
///
/// **刻意语义(勿"顺手修复")**:写入走「先改内存、再写盘、写盘失败静默」——
/// 内存态与磁盘态允许不一致,保持选择立即可用;读盘失败也全吞归未选择。
@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
class ExternalPlayerPreference extends _$ExternalPlayerPreference
    with AsyncNotifierDisposeGuardMixin<ExternalPlayerSelection> {
  static const String _packageKey = 'android.external_player.package_name';
  static const String _labelKey = 'android.external_player.label';

  @override
  Future<ExternalPlayerSelection> build() async {
    attachDisposeGuard();
    try {
      final preferences = await SharedPreferences.getInstance();
      final storedPackage = preferences.getString(_packageKey);
      final packageName =
          storedPackage != null && storedPackage.isNotEmpty
              ? storedPackage
              : null;
      return ExternalPlayerSelection(
        packageName: packageName,
        label: packageName == null ? null : preferences.getString(_labelKey),
      );
    } catch (_) {
      return const ExternalPlayerSelection();
    }
  }

  Future<void> selectExternalPlayer({
    required String packageName,
    required String label,
  }) async {
    final current = state.value ?? const ExternalPlayerSelection();
    if (current.packageName == packageName && current.label == label) {
      return;
    }
    state = AsyncData(
      ExternalPlayerSelection(packageName: packageName, label: label),
    );
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_packageKey, packageName);
      await preferences.setString(_labelKey, label);
    } catch (_) {
      // 忽略持久化失败，保持内存态可用。
    }
  }

  Future<void> useInAppPlayer() async {
    final current = state.value;
    if (current == null || !current.hasExternalPlayer) {
      return;
    }
    state = const AsyncData(ExternalPlayerSelection());
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_packageKey);
      await preferences.remove(_labelKey);
    } catch (_) {
      // 忽略持久化失败，保持内存态可用。
    }
  }
}
