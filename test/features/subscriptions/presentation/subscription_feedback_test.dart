import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/actors/presentation/actor_subscription_toggle_result.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_toggle_result.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations_en.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

/// 中日韩统一表意文字，用于判定「英文界面漏出中文」。
final RegExp _cjk = RegExp(r'[\u4e00-\u9fff]');

void main() {
  test('movieSubscriptionFeedbackMessage follows the caller locale', () {
    // 英文界面不得出现中文：订阅反馈曾经缺 l10n 就静默回退中文。
    final en = movieSubscriptionFeedbackMessage(
      const MovieSubscriptionToggleResult.subscribed(),
      l10n: AppLocalizationsEn(),
    );
    expect(en, isNotNull);
    expect(_cjk.hasMatch(en!), isFalse);

    final zh = movieSubscriptionFeedbackMessage(
      const MovieSubscriptionToggleResult.subscribed(),
      l10n: AppLocalizationsZh(),
    );
    expect(zh, isNotNull);
    expect(_cjk.hasMatch(zh!), isTrue);
  });

  test('actorSubscriptionFeedbackMessage follows the caller locale', () {
    final en = actorSubscriptionFeedbackMessage(
      const ActorSubscriptionToggleResult.subscribed(),
      l10n: AppLocalizationsEn(),
    );
    expect(en, isNotNull);
    expect(_cjk.hasMatch(en!), isFalse);

    final zh = actorSubscriptionFeedbackMessage(
      const ActorSubscriptionToggleResult.subscribed(),
      l10n: AppLocalizationsZh(),
    );
    expect(zh, isNotNull);
    expect(_cjk.hasMatch(zh!), isTrue);
  });

  test('movieSubscriptionFeedbackMessage maps toggle states', () {
    final l10n = AppLocalizationsZh();

    // 失败态透传后端返回的消息，不替换成通用文案。
    expect(
      movieSubscriptionFeedbackMessage(
        const MovieSubscriptionToggleResult.failed(message: 'boom'),
        l10n: l10n,
      ),
      'boom',
    );
    // 忽略态没有新变化，不打扰用户。
    expect(
      movieSubscriptionFeedbackMessage(
        const MovieSubscriptionToggleResult.ignored(),
        l10n: l10n,
      ),
      isNull,
    );
    // 订阅 / 取消订阅 / 被媒体阻挡必须给出可区分的提示。
    final messages = <String?>{
      movieSubscriptionFeedbackMessage(
        const MovieSubscriptionToggleResult.subscribed(),
        l10n: l10n,
      ),
      movieSubscriptionFeedbackMessage(
        const MovieSubscriptionToggleResult.unsubscribed(),
        l10n: l10n,
      ),
      movieSubscriptionFeedbackMessage(
        const MovieSubscriptionToggleResult.blockedByMedia(),
        l10n: l10n,
      ),
    };
    expect(messages.length, 3);
  });

  test('actorSubscriptionFeedbackMessage maps toggle states', () {
    final l10n = AppLocalizationsZh();

    expect(
      actorSubscriptionFeedbackMessage(
        const ActorSubscriptionToggleResult.failed(message: 'boom'),
        l10n: l10n,
      ),
      'boom',
    );
    expect(
      actorSubscriptionFeedbackMessage(
        const ActorSubscriptionToggleResult.ignored(),
        l10n: l10n,
      ),
      isNull,
    );

    final messages = <String?>{
      actorSubscriptionFeedbackMessage(
        const ActorSubscriptionToggleResult.subscribed(),
        l10n: l10n,
      ),
      actorSubscriptionFeedbackMessage(
        const ActorSubscriptionToggleResult.unsubscribed(),
        l10n: l10n,
      ),
    };
    expect(messages.length, 2);
  });
}
