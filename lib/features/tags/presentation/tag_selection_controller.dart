import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/movie_filter_state.dart';
import 'package:sakuramedia/features/tags/data/tag_list_item_dto.dart';
import 'package:sakuramedia/features/tags/data/tags_api.dart';

/// 标签选择区的状态：负责加载全部标签、搜索过滤、展开/收起与多选。
class TagSelectionController extends ChangeNotifier {
  TagSelectionController({
    required TagsApi tagsApi,
    this.popularLimit = 60,
    List<int> initialSelectedTagIds = const <int>[],
    TagMatchMode initialMatchMode = TagMatchMode.or,
  }) : _tagsApi = tagsApi,
       _matchMode = initialMatchMode {
    _selectedTagIds.addAll(initialSelectedTagIds);
  }

  final TagsApi _tagsApi;

  /// 未搜索时默认展示的热门标签数量。
  final int popularLimit;

  List<TagListItemDto> _allTags = const <TagListItemDto>[];
  final Map<int, TagListItemDto> _tagById = <int, TagListItemDto>{};
  final Set<int> _selectedTagIds = <int>{};
  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  String? _errorMessage;
  String _searchQuery = '';
  bool _expanded = false;
  TagMatchMode _matchMode;

  List<TagListItemDto> get allTags => _allTags;
  bool get isLoading => _isLoading;
  bool get hasLoadedOnce => _hasLoadedOnce;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  bool get isSearching => _searchQuery.trim().isNotEmpty;
  bool get expanded => _expanded;

  /// 多标签组合关系：`or` 命中任一，`and` 须同时命中全部。
  TagMatchMode get matchMode => _matchMode;

  /// 已选标签 ID（保留选择顺序）。
  List<int> get selectedTagIds => List<int>.unmodifiable(_selectedTagIds);
  int get selectedCount => _selectedTagIds.length;
  bool get hasSelection => _selectedTagIds.isNotEmpty;
  bool isSelected(int tagId) => _selectedTagIds.contains(tagId);

  /// 已选标签的完整信息（用于渲染已选 chips）。
  List<TagListItemDto> get selectedTags => _selectedTagIds
      .map((id) => _tagById[id])
      .whereType<TagListItemDto>()
      .toList(growable: false);

  /// 标签云当前应展示的标签：
  /// - 有搜索词：对全量按名称子串过滤；
  /// - 无搜索词：取热门前 N（接口已按影片数降序）。
  List<TagListItemDto> get visibleTags {
    final keyword = _searchQuery.trim().toLowerCase();
    if (keyword.isNotEmpty) {
      return _allTags
          .where((tag) => tag.name.toLowerCase().contains(keyword))
          .toList(growable: false);
    }
    if (_allTags.length <= popularLimit) {
      return _allTags;
    }
    return _allTags.sublist(0, popularLimit);
  }

  Future<void> load() async {
    if (_isLoading) {
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final tags = await _tagsApi.getTags();
      _allTags = tags;
      _tagById
        ..clear()
        ..addEntries(tags.map((tag) => MapEntry(tag.tagId, tag)));
      _hasLoadedOnce = true;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = apiErrorMessage(
        error,
        fallback: '标签加载失败，请稍后重试',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> retry() => load();

  void setQuery(String value) {
    if (_searchQuery == value) {
      return;
    }
    _searchQuery = value;
    notifyListeners();
  }

  void toggleExpanded() {
    _expanded = !_expanded;
    notifyListeners();
  }

  void setMatchMode(TagMatchMode mode) {
    if (_matchMode == mode) {
      return;
    }
    _matchMode = mode;
    notifyListeners();
  }

  void toggle(int tagId) {
    if (_selectedTagIds.contains(tagId)) {
      _selectedTagIds.remove(tagId);
    } else {
      _selectedTagIds.add(tagId);
    }
    notifyListeners();
  }

  void remove(int tagId) {
    if (_selectedTagIds.remove(tagId)) {
      notifyListeners();
    }
  }

  void clear() {
    if (_selectedTagIds.isEmpty) {
      return;
    }
    _selectedTagIds.clear();
    notifyListeners();
  }
}
