import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/features/status/presentation/providers/server_capabilities_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/overview/presentation/providers/overview_system_info_state.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/features/status/presentation/providers/status_api_provider.dart';

part 'overview_system_info_provider.g.dart';

/// 系统概览(一次性加载 + 两个手动探针,无轮询)。
///
/// 同步 Notifier + 显式 flags，供桌面/移动概览页分别展示刷新与探针状态；
/// autoDispose，离开页面即释放。
///
/// - [load] 不置 loading 标志([refresh] 才置)——桌面概览页刷新走 [load],
///   卡片不闪骨架;移动页刷新走 [refresh],闪骨架。
/// - 图搜索引状态失败静默（UI 显示「不可用」），不打扰主信息。
@riverpod
class OverviewSystemInfo extends _$OverviewSystemInfo {
  bool _disposed = false;

  /// 趋势请求版本号：窗口切换时丢弃迟到的旧区间回包。
  int _watchTrendRequestVersion = 0;

  @override
  OverviewSystemInfoState build() {
    ref.onDispose(() => _disposed = true);
    // 创建即请求，首帧保持 loading 态（由 State 默认值表达）。
    Future<void>.microtask(load);
    return const OverviewSystemInfoState();
  }

  Future<void> load() async {
    ref.invalidate(serverCapabilitiesProvider);
    await Future.wait<void>([
      loadStatus(),
      loadImageSearchStatus(),
      loadInsights(),
      loadWatchTrend(),
    ]);
  }

  Future<void> refresh() async {
    if (_disposed) return;
    state = state.copyWith(
      isLoadingStatus: true,
      isLoadingImageSearchStatus: true,
      isLoadingInsights: true,
      isLoadingWatchTrend: true,
      statusError: null,
      insightsError: null,
      watchTrendError: null,
    );
    await load();
  }

  Future<void> loadStatus() async {
    try {
      final nextStatus = await ref.read(statusApiProvider).getStatus();
      if (_disposed) return;
      state = state.copyWith(status: nextStatus, statusError: null);
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(
        statusError: ref
            .read(appLocalizationsProvider)
            .overviewStatusLoadFailed,
      );
    } finally {
      if (!_disposed) {
        state = state.copyWith(isLoadingStatus: false);
      }
    }
  }

  Future<void> loadInsights() async {
    try {
      final next = await ref.read(statusApiProvider).getInsights();
      if (_disposed) return;
      state = state.copyWith(insights: next, insightsError: null);
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(
        insightsError: ref
            .read(appLocalizationsProvider)
            .overviewInsightsLoadFailed,
      );
    } finally {
      if (!_disposed) {
        state = state.copyWith(isLoadingInsights: false);
      }
    }
  }

  Future<void> loadWatchTrend() async {
    final range = state.watchTrendRange;
    final version = ++_watchTrendRequestVersion;
    try {
      final next = await ref.read(statusApiProvider).getWatchTrend(range);
      if (_disposed || version != _watchTrendRequestVersion) return;
      state = state.copyWith(watchTrend: next, watchTrendError: null);
    } catch (_) {
      if (_disposed || version != _watchTrendRequestVersion) return;
      state = state.copyWith(
        watchTrendError: ref
            .read(appLocalizationsProvider)
            .overviewWatchTrendLoadFailed,
      );
    } finally {
      if (!_disposed && version == _watchTrendRequestVersion) {
        state = state.copyWith(isLoadingWatchTrend: false);
      }
    }
  }

  /// 切换趋势时间窗口；同一窗口直接返回，不重复请求。
  Future<void> setWatchTrendRange(WatchTrendRange range) async {
    if (_disposed || range == state.watchTrendRange) {
      return;
    }
    state = state.copyWith(
      watchTrendRange: range,
      isLoadingWatchTrend: true,
      watchTrendError: null,
    );
    await loadWatchTrend();
  }

  Future<void> loadImageSearchStatus() async {
    try {
      final next = await ref.read(statusApiProvider).getImageSearchStatus();
      if (_disposed) return;
      state = state.copyWith(imageSearchStatus: next);
    } catch (_) {
      if (_disposed) return;
      // 刻意静默:识别索引状态失败只显示「不可用」,不打扰主信息。
      state = state.copyWith(imageSearchStatus: null);
    } finally {
      if (!_disposed) {
        state = state.copyWith(isLoadingImageSearchStatus: false);
      }
    }
  }

  Future<void> resetImageSearch() async {
    if (_disposed || state.isResettingImageSearch) {
      return;
    }
    state = state.copyWith(isResettingImageSearch: true);
    try {
      await ref.read(statusApiProvider).resetImageSearch();
      await loadImageSearchStatus();
    } finally {
      if (!_disposed) {
        state = state.copyWith(isResettingImageSearch: false);
      }
    }
  }
}
