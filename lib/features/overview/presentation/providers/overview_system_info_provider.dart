import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/overview/presentation/providers/overview_system_info_state.dart';
import 'package:sakuramedia/features/status/presentation/providers/status_api_provider.dart';

part 'overview_system_info_provider.g.dart';

/// 系统概览(一次性加载 + 两个手动探针,无轮询)。
///
/// 迁移前对应 `OverviewSystemInfoController`。同步 Notifier + 显式 flags:
/// UI 依赖「刷新中 isLoadingStatus=true 且旧 status 保留」等复合态。
/// autoDispose:离开页面即释放。
///
/// 与旧控制器一致的两点(勿"顺手统一"):
/// - [load] 不置 loading 标志([refresh] 才置)——桌面概览页刷新走 [load],
///   统计条不闪骨架;移动页刷新走 [refresh],闪骨架。
/// - 两个探针带「进行中直接 return」重入锁;两条加载腿无重入锁(与旧同)。
@riverpod
class OverviewSystemInfo extends _$OverviewSystemInfo {
  bool _disposed = false;

  @override
  OverviewSystemInfoState build() {
    ref.onDispose(() => _disposed = true);
    // 对齐旧消费方 `OverviewSystemInfoController(...)..load()`:创建即请求,
    // 首帧即处于双 loading 态(State 默认值)。
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

  Future<void> testCloud115Authentication() async {
    if (state.isTestingCloud115Authentication) {
      return;
    }

    state = state.copyWith(
      isTestingCloud115Authentication: true,
      cloud115AuthenticationRequestFailed: false,
      cloud115CookiesStatus: null,
    );

    try {
      final next = await ref.read(statusApiProvider).getCloud115CookiesStatus();
      if (_disposed) return;
      state = state.copyWith(cloud115CookiesStatus: next);
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(cloud115AuthenticationRequestFailed: true);
    } finally {
      if (!_disposed) {
        state = state.copyWith(isTestingCloud115Authentication: false);
      }
    }
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
