import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/tags/data/tag_list_item_dto.dart';

const Object _tagSelectionUnset = Object();

@immutable
class TagSelectionState {
  const TagSelectionState({
    this.allTags = const <TagListItemDto>[],
    this.selectedTagIds = const <int>[],
    this.isLoading = false,
    this.hasLoadedOnce = false,
    this.errorMessage,
    this.searchQuery = '',
    this.expanded = false,
    this.matchMode = TagMatchMode.or,
  });

  final List<TagListItemDto> allTags;
  final List<int> selectedTagIds;
  final bool isLoading;
  final bool hasLoadedOnce;
  final String? errorMessage;
  final String searchQuery;
  final bool expanded;
  final TagMatchMode matchMode;

  bool get isSearching => searchQuery.trim().isNotEmpty;
  int get selectedCount => selectedTagIds.length;
  bool get hasSelection => selectedTagIds.isNotEmpty;
  bool isSelected(int tagId) => selectedTagIds.contains(tagId);

  List<TagListItemDto> get selectedTags {
    final byId = <int, TagListItemDto>{
      for (final tag in allTags) tag.tagId: tag,
    };
    return List<TagListItemDto>.unmodifiable(
      selectedTagIds.map((id) => byId[id]).whereType<TagListItemDto>(),
    );
  }

  /// 按搜索词过滤后的标签云数据，不做数量截断；收起态由面板按数量裁剪。
  List<TagListItemDto> get filteredTags {
    final keyword = searchQuery.trim().toLowerCase();
    if (keyword.isEmpty) {
      return allTags;
    }
    return List<TagListItemDto>.unmodifiable(
      allTags.where((tag) => tag.name.toLowerCase().contains(keyword)),
    );
  }

  TagSelectionState copyWith({
    List<TagListItemDto>? allTags,
    List<int>? selectedTagIds,
    bool? isLoading,
    bool? hasLoadedOnce,
    Object? errorMessage = _tagSelectionUnset,
    String? searchQuery,
    bool? expanded,
    TagMatchMode? matchMode,
  }) {
    return TagSelectionState(
      allTags: List<TagListItemDto>.unmodifiable(allTags ?? this.allTags),
      selectedTagIds: List<int>.unmodifiable(
        selectedTagIds ?? this.selectedTagIds,
      ),
      isLoading: isLoading ?? this.isLoading,
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
      errorMessage:
          identical(errorMessage, _tagSelectionUnset)
              ? this.errorMessage
              : errorMessage as String?,
      searchQuery: searchQuery ?? this.searchQuery,
      expanded: expanded ?? this.expanded,
      matchMode: matchMode ?? this.matchMode,
    );
  }
}
