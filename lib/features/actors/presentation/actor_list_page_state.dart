import 'package:sakuramedia/app/app_page_state_cache.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/actors/presentation/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/paged_actor_summary_controller.dart';

class ActorListPageStateEntry implements AppPageStateEntry {
  ActorListPageStateEntry({required ActorsApi actorsApi})
    : _actorsApi = actorsApi {
    controller = PagedActorSummaryController(
      fetchPage:
          (page, pageSize) => _actorsApi.getActors(
            page: page,
            pageSize: pageSize,
            subscriptionStatus: filterState.subscriptionStatus,
            gender: filterState.gender,
          ),
      subscribeActor: _actorsApi.subscribeActor,
      unsubscribeActor: _actorsApi.unsubscribeActor,
      pageSize: 24,
      loadMoreTriggerOffset: 300,
    );
    controller.attachScrollListener();
    controller.initialize();
  }

  final ActorsApi _actorsApi;
  late final PagedActorSummaryController controller;
  ActorFilterState filterState = ActorFilterState.initial;

  @override
  void dispose() {
    controller.dispose();
  }
}
