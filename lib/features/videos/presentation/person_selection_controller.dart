import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/videos/data/person_dto.dart';
import 'package:sakuramedia/features/videos/data/persons_api.dart';

/// 人物筛选区状态：按关键词分页搜索人物、多选，并维护已选 chips。
///
/// 与 [TagSelectionController] 形态对齐，但人物是**分页搜索**接口（不像标签全量返回），
/// 故无搜索词时取首页热门、有搜索词时走服务端 `query`，并对输入做防抖。
class PersonSelectionController extends ChangeNotifier {
  PersonSelectionController({
    required PersonsApi personsApi,
    this.resultLimit = 30,
    this.searchDebounce = const Duration(milliseconds: 300),
    List<PersonDto> initialSelectedPersons = const <PersonDto>[],
  }) : _personsApi = personsApi {
    for (final person in initialSelectedPersons) {
      _selectedPersonIds.add(person.id);
      _personById[person.id] = person;
    }
  }

  final PersonsApi _personsApi;

  /// 单次展示/拉取的人物数量。
  final int resultLimit;
  final Duration searchDebounce;

  List<PersonDto> _results = const <PersonDto>[];
  final Map<int, PersonDto> _personById = <int, PersonDto>{};
  final Set<int> _selectedPersonIds = <int>{};
  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  String? _errorMessage;
  String _searchQuery = '';
  bool _expanded = false;
  Timer? _debounceTimer;

  List<PersonDto> get results => _results;
  bool get isLoading => _isLoading;
  bool get hasLoadedOnce => _hasLoadedOnce;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  bool get isSearching => _searchQuery.trim().isNotEmpty;
  bool get expanded => _expanded;

  List<int> get selectedPersonIds => List<int>.unmodifiable(_selectedPersonIds);
  int get selectedCount => _selectedPersonIds.length;
  bool get hasSelection => _selectedPersonIds.isNotEmpty;
  bool isSelected(int personId) => _selectedPersonIds.contains(personId);

  /// 已选人物的完整信息（用于渲染已选 chips）。
  List<PersonDto> get selectedPersons => _selectedPersonIds
      .map((id) => _personById[id])
      .whereType<PersonDto>()
      .toList(growable: false);

  Future<void> load() => _loadResults();

  Future<void> retry() => _loadResults();

  Future<void> _loadResults() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final page = await _personsApi.getPersons(
        query: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
        page: 1,
        pageSize: resultLimit,
      );
      _results = page.items;
      for (final person in page.items) {
        _personById[person.id] = person;
      }
      _hasLoadedOnce = true;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = apiErrorMessage(error, fallback: '人物加载失败，请稍后重试');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    if (_searchQuery == value) {
      return;
    }
    _searchQuery = value;
    notifyListeners();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(searchDebounce, () {
      unawaited(_loadResults());
    });
  }

  void toggleExpanded() {
    _expanded = !_expanded;
    notifyListeners();
  }

  void toggle(PersonDto person) {
    _personById[person.id] = person;
    if (_selectedPersonIds.contains(person.id)) {
      _selectedPersonIds.remove(person.id);
    } else {
      _selectedPersonIds.add(person.id);
    }
    notifyListeners();
  }

  void remove(int personId) {
    if (_selectedPersonIds.remove(personId)) {
      notifyListeners();
    }
  }

  void clear() {
    if (_selectedPersonIds.isEmpty) {
      return;
    }
    _selectedPersonIds.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
