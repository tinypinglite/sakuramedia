import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/actors/presentation/paged_actor_summary_controller.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';

void main() {
  test(
    'movieSubscriptionFeedbackMessage maps toggle results to toast copy',
    () {
      expect(
        movieSubscriptionFeedbackMessage(
          const MovieSubscriptionToggleResult.subscribed(),
        ),
        '已订阅影片',
      );
      expect(
        movieSubscriptionFeedbackMessage(
          const MovieSubscriptionToggleResult.unsubscribed(),
        ),
        '已取消订阅影片',
      );
      expect(
        movieSubscriptionFeedbackMessage(
          const MovieSubscriptionToggleResult.blockedByMedia(),
        ),
        '该影片存在媒体，默认不能取消订阅',
      );
      expect(
        movieSubscriptionFeedbackMessage(
          const MovieSubscriptionToggleResult.failed(message: 'boom'),
        ),
        'boom',
      );
      expect(
        movieSubscriptionFeedbackMessage(
          const MovieSubscriptionToggleResult.ignored(),
        ),
        isNull,
      );
    },
  );

  test(
    'actorSubscriptionFeedbackMessage maps toggle results to toast copy',
    () {
      expect(
        actorSubscriptionFeedbackMessage(
          const ActorSubscriptionToggleResult.subscribed(),
        ),
        '已订阅女优',
      );
      expect(
        actorSubscriptionFeedbackMessage(
          const ActorSubscriptionToggleResult.unsubscribed(),
        ),
        '已取消订阅女优',
      );
      expect(
        actorSubscriptionFeedbackMessage(
          const ActorSubscriptionToggleResult.failed(message: 'boom'),
        ),
        'boom',
      );
      expect(
        actorSubscriptionFeedbackMessage(
          const ActorSubscriptionToggleResult.ignored(),
        ),
        isNull,
      );
    },
  );
}
