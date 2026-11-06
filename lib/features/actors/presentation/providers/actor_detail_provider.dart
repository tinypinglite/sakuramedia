import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_detail_dto.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_detail_state.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actors_api_provider.dart';
import 'package:sakuramedia/features/recent_views/data/dto/recent_view_dto.dart';
import 'package:sakuramedia/features/recent_views/presentation/recent_view_reporter.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';

part 'actor_detail_provider.g.dart';

/// 女优详情按 id 隔离，离开详情页后自动释放。
@Riverpod(retry: kNoAsyncNotifierRetry)
class ActorDetail extends _$ActorDetail {
  Future<void>? _refreshInFlight;

  @override
  Future<ActorDetailState> build(int actorId) => _fetch();

  Future<void> reload() async {
    if (state.isLoading) {
      return;
    }
    state = const AsyncLoading<ActorDetailState>();
    state = AsyncData(await _fetch());
  }

  /// 顶栏主动刷新失败时保留当前详情并向页面抛错，以延续原 toast 语义。
  ///
  /// 自身不上报浏览：与 movie 详情一致，只由页面手势刷新（下拉 / 顶栏，
  /// refresh 成功后显式调 [reportView]）与首载 [build] 上报；后台同步
  /// （如管理页改名后重拉）走这里，不应把用户没打开的详情顶进「最近浏览」。
  ///
  /// 并发去重：快速连续触发（下拉 + 顶栏）共享在途 Future，
  /// 避免两个请求乱序返回时旧响应覆盖新响应。
  Future<void> refresh() => _refreshInFlight ??= _refresh().whenComplete(
    () => _refreshInFlight = null,
  );

  Future<void> _refresh() async {
    final current = state.value;
    if (current?.actor == null || state.isLoading) {
      return;
    }
    final actor = await ref
        .read(actorsApiProvider)
        .getActorDetail(actorId: actorId);
    if (!ref.mounted) {
      return;
    }
    state = AsyncData(ActorDetailState(actor: actor));
  }

  /// 页面手势刷新（下拉 / 顶栏）成功后显式调用，计入一次浏览。
  void reportView() {
    if (!ref.mounted) {
      return;
    }
    reportRecentView(
      ref,
      entityType: RecentViewEntityType.actor,
      entityId: actorId,
    );
  }

  void replaceActor(ActorDetailDto actor) {
    if (!ref.mounted) {
      return;
    }
    state = AsyncData(ActorDetailState(actor: actor));
  }

  Future<ActorDetailState> _fetch() async {
    try {
      final actor = await ref
          .read(actorsApiProvider)
          .getActorDetail(actorId: actorId);
      if (ref.mounted) {
        reportRecentView(
          ref,
          entityType: RecentViewEntityType.actor,
          entityId: actorId,
        );
      }
      return ActorDetailState(actor: actor);
    } catch (error) {
      return ActorDetailState(errorMessage: _messageForError(error));
    }
  }

  String _messageForError(Object error) {
    final l10n = ref.read(appLocalizationsProvider);
    if (error is ApiException &&
        (error.statusCode == 404 || error.error?.code == 'actor_not_found')) {
      return l10n.actorDetailNotFound;
    }
    return l10n.actorDetailLoadFailed;
  }
}
