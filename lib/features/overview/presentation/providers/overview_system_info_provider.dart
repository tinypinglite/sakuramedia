import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/overview/presentation/providers/overview_system_info_state.dart';
import 'package:sakuramedia/features/status/presentation/providers/status_api_provider.dart';

part 'overview_system_info_provider.g.dart';

/// 系统概览(一次性加载 + 两个手动探针,无轮询)。
///
/// 同步 Notifier + 显式 flags，供桌面/移动概览页分别展示刷新与探针状态；
/// autoDispose，离开页面即释放。
///
/// - [load] 不置 loading 标志([refresh] 才置)——桌面概览页刷新走 [load],
///   统计条不闪骨架;移动页刷新走 [refresh],闪骨架。
/// - 元数据源探针进行中直接 return；系统信息与图片搜索两条加载腿不加重入锁。
@riverpod
class OverviewSystemInfo extends _$OverviewSystemInfo {
  bool _disposed = false;

  @override
  OverviewSystemInfoState build() {
    ref.onDispose(() => _disposed = true);
    // 创建即请求，首帧保持双 loading 态（由 State 默认值表达）。
    Future<void>.microtask(load);
    return const OverviewSystemInfoState();
  }

  Future<void> load() async {
    await Future.wait<void>([loadStatus(), loadImageSearchStatus()]);
  }

  Future<void> refresh() async {
    if (_disposed) return;
    state = state.copyWith(
      isLoadingStatus: true,
      isLoadingImageSearchStatus: true,
      statusError: null,
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
      state = state.copyWith(statusError: '系统信息加载失败，请稍后重试');
    } finally {
      if (!_disposed) {
        state = state.copyWith(isLoadingStatus: false);
      }
    }
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

  Future<void> testExternalDataSources() async {
    if (state.isTestingMetadataProviders) {
      return;
    }

    state = state.copyWith(isTestingMetadataProviders: true);

    final javdbHealthy = await _testMetadataProvider('javdb');

    if (_disposed) return;
    state = state.copyWith(
      javdbHealthy: javdbHealthy,
      isTestingMetadataProviders: false,
    );
  }

  Future<bool> _testMetadataProvider(String provider) async {
    try {
      final result = await ref
          .read(statusApiProvider)
          .testMetadataProvider(provider);
      return result.healthy;
    } catch (_) {
      return false;
    }
  }
}
