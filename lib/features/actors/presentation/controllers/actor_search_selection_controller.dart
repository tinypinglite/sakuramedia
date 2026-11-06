import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/actors/data/api/actors_api.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

/// 女优搜索与多选状态；创建/合并提交留在各自弹层。
class ActorSearchSelectionController extends ChangeNotifier {
  ActorSearchSelectionController({
    required this.api,
    required this.l10n,
    required this.searchFailedMessage,
    this.excludedActorIds = const <int>{},
  });

  static const Duration debounceDuration = Duration(milliseconds: 300);

  final ActorsApi api;
  final AppLocalizations Function() l10n;
  final String Function(AppLocalizations l10n) searchFailedMessage;
  final Set<int> excludedActorIds;

  final TextEditingController searchController = TextEditingController();
  final Map<int, ActorListItemDto> _selected = <int, ActorListItemDto>{};

  Timer? _debounce;
  int _requestId = 0;
  bool _disposed = false;

  List<ActorListItemDto> _candidates = const <ActorListItemDto>[];
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _searchErrorMessage;

  List<ActorListItemDto> get candidates => _candidates;
  bool get isSearching => _isSearching;
  bool get hasSearched => _hasSearched;
  String? get searchErrorMessage => _searchErrorMessage;
  String get query => searchController.text.trim();

  int get selectedCount => _selected.length;
  List<ActorListItemDto> get selectedActors =>
      List<ActorListItemDto>.unmodifiable(_selected.values);
  List<int> get selectedIds => List<int>.unmodifiable(_selected.keys);
  bool isSelected(int actorId) => _selected.containsKey(actorId);

  void onQueryChanged(String value) {
    _debounce?.cancel();
    _requestId++;
    final normalized = value.trim();
    if (normalized.isEmpty) {
      _candidates = const <ActorListItemDto>[];
      _hasSearched = false;
      _isSearching = false;
      _searchErrorMessage = null;
      _notify();
      return;
    }
    _debounce = Timer(debounceDuration, () => unawaited(_search(normalized)));
  }

  void submitSearch(String value) {
    _debounce?.cancel();
    final normalized = value.trim();
    if (normalized.isNotEmpty) unawaited(_search(normalized));
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    _isSearching = true;
    _searchErrorMessage = null;
    _notify();
    try {
      final page = await api.getActors(
        query: query,
        pageSize: 20,
        subscriptionStatus: ActorSubscriptionStatus.all,
        gender: ActorGender.all,
      );
      if (_disposed || requestId != _requestId) return;
      _candidates = page.items
          .where((actor) => !excludedActorIds.contains(actor.id))
          .toList(growable: false);
      _hasSearched = true;
      _isSearching = false;
      _notify();
    } catch (error) {
      if (_disposed || requestId != _requestId) return;
      final localizations = l10n();
      _hasSearched = true;
      _isSearching = false;
      _searchErrorMessage = apiErrorMessage(
        error,
        fallback: searchFailedMessage(localizations),
        l10n: localizations,
      );
      _notify();
    }
  }

  void toggle(ActorListItemDto actor) {
    if (_selected.remove(actor.id) == null) _selected[actor.id] = actor;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }
}
