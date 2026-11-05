import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actors_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/tags/data/tag_list_item_dto.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_state.dart';

part 'actor_tag_filter_provider.g.dart';

/// 女优详情作品区的标签条件与当前女优作品标签。
///
/// 标签列表只在该面板首次打开时加载，接口返回的 `movie_count` 已经按当前
/// 女优的作品统计；选择状态由本 provider 持有，关闭面板后继续保留。
@riverpod
class ActorTagFilter extends _$ActorTagFilter {
  @override
  TagSelectionState build(int actorId) => const TagSelectionState();

  Future<void> load() async {
    if (state.isLoading || state.hasLoadedOnce) {
      return;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final tags = await ref
          .read(actorsApiProvider)
          .getActorTags(actorId: actorId);
      if (!ref.mounted) {
        return;
      }
      final sortedTags = List<TagListItemDto>.of(tags)
        ..sort((left, right) {
          final countOrder = right.movieCount.compareTo(left.movieCount);
          return countOrder != 0 ? countOrder : left.name.compareTo(right.name);
        });
      state = state.copyWith(
        allTags: sortedTags,
        isLoading: false,
        hasLoadedOnce: true,
        errorMessage: null,
      );
    } catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: ref.apiErrorMessage(
          error,
          fallback: ref.read(appLocalizationsProvider).errorTagLoadFailed,
        ),
      );
    }
  }

  void toggle(int tagId) {
    final next = List<int>.of(state.selectedTagIds);
    if (!next.remove(tagId)) {
      next.add(tagId);
    }
    state = state.copyWith(selectedTagIds: next);
  }

  void remove(int tagId) {
    final next = List<int>.of(state.selectedTagIds)..remove(tagId);
    if (next.length != state.selectedTagIds.length) {
      state = state.copyWith(selectedTagIds: next);
    }
  }

  void clear() {
    if (state.hasSelection) {
      state = state.copyWith(selectedTagIds: const <int>[]);
    }
  }

  void setMatchMode(TagMatchMode mode) {
    if (state.matchMode != mode) {
      state = state.copyWith(matchMode: mode);
    }
  }
}
