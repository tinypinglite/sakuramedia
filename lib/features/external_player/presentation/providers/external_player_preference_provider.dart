import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/external_player/data/external_player_selection.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'external_player_preference_provider.g.dart';

/// 「默认外部播放器」偏好（keepAlive AsyncNotifier）。
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
  static String get _playerIdKey => switch (defaultTargetPlatform) {
    // 保留 Android 已发布版本的键，已有选择升级后无需重选。
    TargetPlatform.android => 'android.external_player.package_name',
    TargetPlatform.macOS => 'macos.external_player.application_path',
    TargetPlatform.windows => 'windows.external_player.application_path',
    _ => 'external_player.player_id',
  };

  static String get _labelKey => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android.external_player.label',
    TargetPlatform.macOS => 'macos.external_player.label',
    TargetPlatform.windows => 'windows.external_player.label',
    _ => 'external_player.label',
  };

  @override
  Future<ExternalPlayerSelection> build() async {
    attachDisposeGuard();
    try {
      final preferences = await SharedPreferences.getInstance();
      final storedPlayerId = preferences.getString(_playerIdKey);
      final playerId = storedPlayerId != null && storedPlayerId.isNotEmpty
          ? storedPlayerId
          : null;
      return ExternalPlayerSelection(
        playerId: playerId,
        label: playerId == null ? null : preferences.getString(_labelKey),
      );
    } catch (_) {
      return const ExternalPlayerSelection();
    }
  }

  Future<void> selectExternalPlayer({
    required String playerId,
    required String label,
  }) async {
    final current = state.value ?? const ExternalPlayerSelection();
    if (current.playerId == playerId && current.label == label) {
      return;
    }
    state = AsyncData(
      ExternalPlayerSelection(playerId: playerId, label: label),
    );
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_playerIdKey, playerId);
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
      await preferences.remove(_playerIdKey);
      await preferences.remove(_labelKey);
    } catch (_) {
      // 忽略持久化失败，保持内存态可用。
    }
  }
}
