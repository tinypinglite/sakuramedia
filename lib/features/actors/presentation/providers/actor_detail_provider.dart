import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_detail_dto.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_detail_state.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actors_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';

part 'actor_detail_provider.g.dart';

/// 女优详情按 id 隔离，离开详情页后自动释放。
@Riverpod(retry: kNoAsyncNotifierRetry)
class ActorDetail extends _$ActorDetail {
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
  Future<void> refresh() async {
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
    state = AsyncData(current!.copyWith(actor: actor, errorMessage: null));
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
      return ActorDetailState(actor: actor);
    } catch (error) {
      return ActorDetailState(errorMessage: _messageForError(error));
    }
  }

  String _messageForError(Object error) {
    if (error is ApiException &&
        (error.statusCode == 404 || error.error?.code == 'actor_not_found')) {
      return '未找到该女优';
    }
    return '女优详情暂时无法加载，请稍后重试';
  }
}
