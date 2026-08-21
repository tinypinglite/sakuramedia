import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/discovery/data/daily_recommendation_movie_dto.dart';
import 'package:sakuramedia/features/discovery/data/hot_actress_release_movie_dto.dart';
import 'package:sakuramedia/features/discovery/data/moment_recommendation_dto.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/hot_actress_release_subscription_changes.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/discovery_api_provider.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/discovery_preview_state.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';

part 'discovery_preview_providers.g.dart';

/// 发现首屏「今日推荐」预览(只拉 page 1,不分页;family 参数=预览条数,
/// 桌面 6 / 移动 10)。
///
/// 迁移前对应 `DiscoveryController` 的 daily 半边;两条腿拆成独立 provider,
/// 天然获得「一侧失败不拖垮另一侧」(与旧双字段对称结构等价)。
/// autoDispose:离开页面即释放。同步 Notifier + 显式 flags(而非 AsyncNotifier),
/// 因为旧 UI 依赖「refresh 进行中 isLoading=true 且 items 保留」的复合态。
@riverpod
class DiscoveryDailyPreview extends _$DiscoveryDailyPreview {
  bool _disposed = false;
  bool _inFlight = false;

  @override
  DiscoveryPreviewState<DailyRecommendationMovieDto> build(int pageSize) {
    ref.onDispose(() => _disposed = true);
    // 对齐旧消费方 `DiscoveryController(...)..load()`:创建即请求,
    // 首帧即处于 loading 态。
    Future<void>.microtask(load);
    return const DiscoveryPreviewState(isLoading: true);
  }

  Future<void> load() => _fetch(clearExisting: true);

  Future<void> refresh() => _fetch(clearExisting: false);

  Future<void> _fetch({required bool clearExisting}) async {
    if (_inFlight) {
      return;
    }
    _inFlight = true;
    state = DiscoveryPreviewState(
      items: clearExisting
          ? const <DailyRecommendationMovieDto>[]
          : state.items,
      total: clearExisting ? 0 : state.total,
      isLoading: true,
    );
    try {
      final response = await ref
          .read(discoveryApiProvider)
          .getDailyRecommendations(page: 1, pageSize: pageSize);
      if (_disposed) {
        return;
      }
      state = DiscoveryPreviewState(
        items: List<DailyRecommendationMovieDto>.unmodifiable(response.items),
        total: response.total,
      );
    } catch (_) {
      if (_disposed) {
        return;
      }
      // refresh 失败且已有旧数据:静默保留,不置错。
      final keepSilently = !clearExisting && state.items.isNotEmpty;
      state = DiscoveryPreviewState(
        items: state.items,
        total: state.total,
        errorMessage: keepSilently ? null : '今日推荐加载失败，请稍后重试',
      );
    } finally {
      _inFlight = false;
    }
  }
}

@riverpod
class DiscoveryHotActressReleasePreview
    extends _$DiscoveryHotActressReleasePreview {
  bool _disposed = false;
  bool _inFlight = false;

  @override
  DiscoveryPreviewState<HotActressReleaseMovieDto> build(int pageSize) {
    ref.onDispose(() => _disposed = true);
    ref.listen(movieSubscriptionEventsProvider, (_, next) {
      final changes = next.value;
      if (changes == null) return;
      final items = state.items.withSubscriptionChanges(changes);
      if (!identical(items, state.items)) {
        state = DiscoveryPreviewState(
          items: items,
          total: state.total,
          isLoading: state.isLoading,
          errorMessage: state.errorMessage,
        );
      }
    });
    Future<void>.microtask(load);
    return const DiscoveryPreviewState(isLoading: true);
  }

  Future<void> load() => _fetch(clearExisting: true);

  Future<void> refresh() => _fetch(clearExisting: false);

  Future<void> _fetch({required bool clearExisting}) async {
    if (_inFlight) return;
    _inFlight = true;
    state = DiscoveryPreviewState(
      items: clearExisting ? const <HotActressReleaseMovieDto>[] : state.items,
      total: clearExisting ? 0 : state.total,
      isLoading: true,
    );
    try {
      final response = await ref
          .read(discoveryApiProvider)
          .getHotActressReleases(page: 1, pageSize: pageSize);
      if (_disposed) return;
      state = DiscoveryPreviewState(
        items: List<HotActressReleaseMovieDto>.unmodifiable(response.items),
        total: response.total,
      );
    } catch (_) {
      if (_disposed) return;
      final keepSilently = !clearExisting && state.items.isNotEmpty;
      state = DiscoveryPreviewState(
        items: state.items,
        total: state.total,
        errorMessage: keepSilently ? null : '热门女优新片加载失败，请稍后重试',
      );
    } finally {
      _inFlight = false;
    }
  }
}

/// 发现首屏「推荐时刻」预览,同上(family 参数=预览条数,桌面 8 / 移动 10)。
@riverpod
class DiscoveryMomentPreview extends _$DiscoveryMomentPreview {
  bool _disposed = false;
  bool _inFlight = false;

  @override
  DiscoveryPreviewState<MomentRecommendationDto> build(int pageSize) {
    ref.onDispose(() => _disposed = true);
    Future<void>.microtask(load);
    return const DiscoveryPreviewState(isLoading: true);
  }

  Future<void> load() => _fetch(clearExisting: true);

  Future<void> refresh() => _fetch(clearExisting: false);

  Future<void> _fetch({required bool clearExisting}) async {
    if (_inFlight) {
      return;
    }
    _inFlight = true;
    state = DiscoveryPreviewState(
      items: clearExisting ? const <MomentRecommendationDto>[] : state.items,
      total: clearExisting ? 0 : state.total,
      isLoading: true,
    );
    try {
      final response = await ref
          .read(discoveryApiProvider)
          .getMomentRecommendations(page: 1, pageSize: pageSize);
      if (_disposed) {
        return;
      }
      state = DiscoveryPreviewState(
        items: List<MomentRecommendationDto>.unmodifiable(response.items),
        total: response.total,
      );
    } catch (_) {
      if (_disposed) {
        return;
      }
      final keepSilently = !clearExisting && state.items.isNotEmpty;
      state = DiscoveryPreviewState(
        items: state.items,
        total: state.total,
        errorMessage: keepSilently ? null : '推荐时刻加载失败，请稍后重试',
      );
    } finally {
      _inFlight = false;
    }
  }
}
