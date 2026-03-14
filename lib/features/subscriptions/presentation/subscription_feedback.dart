import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/features/actors/presentation/paged_actor_summary_controller.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';

String? movieSubscriptionFeedbackMessage(MovieSubscriptionToggleResult result) {
  switch (result.status) {
    case MovieSubscriptionToggleStatus.subscribed:
      return '已订阅影片';
    case MovieSubscriptionToggleStatus.unsubscribed:
      return '已取消订阅影片';
    case MovieSubscriptionToggleStatus.blockedByMedia:
      return '该影片存在媒体，默认不能取消订阅';
    case MovieSubscriptionToggleStatus.failed:
      return result.message;
    case MovieSubscriptionToggleStatus.ignored:
      return null;
  }
}

String? actorSubscriptionFeedbackMessage(ActorSubscriptionToggleResult result) {
  switch (result.status) {
    case ActorSubscriptionToggleStatus.subscribed:
      return '已订阅女优';
    case ActorSubscriptionToggleStatus.unsubscribed:
      return '已取消订阅女优';
    case ActorSubscriptionToggleStatus.failed:
      return result.message;
    case ActorSubscriptionToggleStatus.ignored:
      return null;
  }
}

void showMovieSubscriptionFeedback(MovieSubscriptionToggleResult result) {
  _showSubscriptionFeedback(movieSubscriptionFeedbackMessage(result));
}

void showActorSubscriptionFeedback(ActorSubscriptionToggleResult result) {
  _showSubscriptionFeedback(actorSubscriptionFeedbackMessage(result));
}

void _showSubscriptionFeedback(String? message) {
  if (message == null || message.isEmpty) {
    return;
  }
  showToast(message);
}
