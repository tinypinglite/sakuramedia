import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status_counts_dto.dart';
import 'package:sakuramedia/features/subscriptions/presentation/providers/movie_subscriptions_api_provider.dart';

part 'movie_subscription_status_counts_provider.g.dart';

/// 状态分段签的角标计数。
///
/// **刻意与列表 provider 分开**：计数挂了不该把整页拖成错误态——分段签退化成没有
/// 角标的纯文字签，列表照常可用。反过来列表翻页也不必反复重算计数。
///
/// 任何会改变状态归属的动作（重置查询 / 取消订阅）之后由列表 notifier 调
/// [MovieSubscriptionStatusCounts.refresh] 拉一次，保持角标与列表同步。
@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
class MovieSubscriptionStatusCounts extends _$MovieSubscriptionStatusCounts
    with AsyncNotifierDisposeGuardMixin<MovieSubscriptionStatusCountsDto> {
  @override
  Future<MovieSubscriptionStatusCountsDto> build() async {
    invalidateOnSessionChange(ref);
    attachDisposeGuard();
    return ref.read(movieSubscriptionsApiProvider).getStatusCounts();
  }

  /// 保留态刷新：不切 [AsyncLoading]，失败静默保留旧计数。
  ///
  /// 计数是辅助信息，失败弹 toast 只会在批量操作后叠一层噪音——真正的操作结果
  /// 反馈由调用方自己给。
  Future<void> refresh() async {
    try {
      final counts =
          await ref.read(movieSubscriptionsApiProvider).getStatusCounts();
      if (isDisposed) return;
      state = AsyncData(counts);
    } catch (_) {
      // 保留上一份计数：陈旧角标也好过角标突然消失。
    }
  }
}
