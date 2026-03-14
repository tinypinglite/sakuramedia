import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/actors/data/actor_list_item_dto.dart';

class ActorDetailController extends ChangeNotifier {
  ActorDetailController({
    required this.actorId,
    required this.fetchActorDetail,
  });

  final int actorId;
  final Future<ActorListItemDto> Function({required int actorId})
  fetchActorDetail;

  ActorListItemDto? _actor;
  bool _isLoading = true;
  String? _errorMessage;

  ActorListItemDto? get actor => _actor;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _actor = await fetchActorDetail(actorId: actorId);
      _errorMessage = null;
    } catch (error) {
      _actor = null;
      _errorMessage = _messageForError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
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
