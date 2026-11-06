import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/features/actors/presentation/actor_subscription_toggle_result.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_subscription_toggle_provider.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_toggle_result.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_subscription_toggle_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

String? movieSubscriptionFeedbackMessage(
  MovieSubscriptionToggleResult result, {
  required AppLocalizations l10n,
}) {
  switch (result.status) {
    case MovieSubscriptionToggleStatus.subscribed:
      return l10n.subscriptionFeedbackMovieSubscribed;
    case MovieSubscriptionToggleStatus.unsubscribed:
      return l10n.subscriptionFeedbackMovieUnsubscribed;
    case MovieSubscriptionToggleStatus.blockedByMedia:
      return l10n.subscriptionFeedbackMovieBlockedByMedia;
    case MovieSubscriptionToggleStatus.failed:
      return result.message;
    case MovieSubscriptionToggleStatus.ignored:
      return null;
  }
}

String? actorSubscriptionFeedbackMessage(
  ActorSubscriptionToggleResult result, {
  required AppLocalizations l10n,
}) {
  switch (result.status) {
    case ActorSubscriptionToggleStatus.subscribed:
      return l10n.subscriptionFeedbackActorSubscribed;
    case ActorSubscriptionToggleStatus.unsubscribed:
      return l10n.subscriptionFeedbackActorUnsubscribed;
    case ActorSubscriptionToggleStatus.failed:
      return result.message;
    case ActorSubscriptionToggleStatus.ignored:
      return null;
  }
}

void showMovieSubscriptionFeedback(
  MovieSubscriptionToggleResult result, {
  required AppLocalizations l10n,
}) {
  _showSubscriptionFeedback(
    movieSubscriptionFeedbackMessage(result, l10n: l10n),
  );
}

void showActorSubscriptionFeedback(
  ActorSubscriptionToggleResult result, {
  required AppLocalizations l10n,
}) {
  _showSubscriptionFeedback(
    actorSubscriptionFeedbackMessage(result, l10n: l10n),
  );
}

/// 女优订阅切换 + 统一 toast 反馈，供各女优卡片入口复用。
Future<void> toggleActorSubscriptionWithFeedback(
  BuildContext context,
  WidgetRef ref, {
  required int actorId,
  required bool isSubscribed,
}) async {
  final result = await ref
      .read(actorSubscriptionToggleProvider.notifier)
      .toggle(actorId: actorId, isSubscribed: isSubscribed);
  if (context.mounted) {
    showActorSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
  }
}

void _showSubscriptionFeedback(String? message) {
  if (message == null || message.isEmpty) {
    return;
  }
  showToast(message);
}

/// 影片批量订阅/取消订阅结果反馈：
/// - 全成功（无 skip） → 一条 toast；
/// - 请求整体失败 → 一条 toast（错误文案已由 controller 侧转成中文）；
/// - 有 skip → 一条摘要 toast + 弹「未处理清单」按原因分组；
/// - 取消订阅被媒体阻挡时可确认强制处理，返回合并结果供页面保留剩余选中项。
///
/// 未处理清单壳由 [showAppAdaptiveModal] 自动分流：桌面走 [AppDesktopDialog]，
/// 移动走 [AppBottomDrawer]。内容是轻量反馈语言——每种跳过原因一个小灰标题 +
/// 一排 [AppBadge] 番号药丸，不套设置页分组卡（番号不可点，用卡壳会误导）。
Future<MovieSubscriptionBatchToggleResult> showMovieSubscriptionBatchFeedback(
  BuildContext context,
  MovieSubscriptionBatchToggleResult result, {
  required bool subscribe,
}) async {
  final l10n = AppLocalizations.of(context);

  if (result.hasError) {
    showToast(
      result.errorMessage ??
          (subscribe
              ? l10n.subscriptionBatchSubscribeFailed
              : l10n.errorBatchUnsubscribeMoviesFailed),
      tone: AppToastTone.error,
    );
    return result;
  }

  if (result.skippedCount == 0) {
    if (result.updatedCount == 0) {
      // 请求成功但无有效变更（例如全部已是目标态），静默不打扰。
      return result;
    }
    showToast(
      subscribe
          ? l10n.subscriptionBatchSubscribedCount(result.updatedCount)
          : l10n.subscriptionBatchUnsubscribedCount(result.updatedCount),
      tone: AppToastTone.success,
    );
    return result;
  }

  if (result.updatedCount > 0) {
    showToast(
      subscribe
          ? l10n.subscriptionBatchSubscribedPartial(
              result.updatedCount,
              result.skippedCount,
            )
          : l10n.subscriptionBatchUnsubscribedPartial(
              result.updatedCount,
              result.skippedCount,
            ),
      tone: AppToastTone.warning,
    );
  } else {
    showToast(
      l10n.subscriptionBatchSkippedCount(result.skippedCount),
      tone: AppToastTone.info,
    );
  }

  if (!context.mounted) {
    return result;
  }

  final force = await showAppAdaptiveModal<bool>(
    context: context,
    modalKey: const Key('movie-list-batch-skipped-modal'),
    // 桌面：番号药丸窄内容，小号对话框宽度足够；抽屉走默认 heightFactor（0.9）。
    desktopWidth: context.appLayoutTokens.dialogWidthSm,
    mobileMaxHeightFactor: 0.85,
    builder: (_) => _MovieSubscriptionBatchSkippedContent(
      result: result,
      subscribe: subscribe,
    ),
  );
  if (force != true || !context.mounted) return result;

  final executor = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(movieSubscriptionToggleProvider.notifier);
  MovieSubscriptionBatchToggleResult? forcedResult;
  final progress = ValueNotifier<MovieForceUnsubscribeProgress?>(null);
  var showProgress = true;
  late final bool confirmed;
  try {
    confirmed = await showAppConfirmDialog(
      context,
      title: l10n.subscriptionForceUnsubscribeTitle,
      message: l10n.subscriptionForceUnsubscribeMessage(
        result.skippedHasMediaNumbers.length,
      ),
      confirmLabel: l10n.subscriptionForceUnsubscribeConfirmLabel,
      danger: true,
      dialogKey: const Key('movie-batch-force-unsubscribe-dialog'),
      confirmKey: const Key('movie-batch-force-unsubscribe-confirm'),
      extraContent: ValueListenableBuilder<MovieForceUnsubscribeProgress?>(
        valueListenable: progress,
        builder: (context, current, _) {
          if (current == null) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: context.appRadius.smBorder,
                child: LinearProgressIndicator(
                  key: const Key('movie-batch-force-unsubscribe-progress'),
                  value: current.value,
                  backgroundColor: context.appColors.surfaceMuted,
                ),
              ),
              SizedBox(height: context.appSpacing.sm),
              Text(
                current.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
            ],
          );
        },
      ),
      onConfirm: () async {
        forcedResult = await executor.forceUnsubscribeBatch(
          result.skippedHasMediaNumbers,
          onProgress: (value) {
            if (showProgress) progress.value = value;
          },
        );
      },
    );
  } finally {
    showProgress = false;
    progress.dispose();
  }
  final forced = forcedResult;
  if (!confirmed || forced == null) return result;
  if (forced.hasError) {
    showToast(forced.errorMessage!, tone: AppToastTone.error);
    return result;
  }
  final combined = MovieSubscriptionBatchToggleResult(
    requestedCount: result.requestedCount,
    updatedCount: result.updatedCount + forced.updatedCount,
    skippedMovieNotFoundNumbers: [
      ...result.skippedMovieNotFoundNumbers,
      ...forced.skippedMovieNotFoundNumbers,
    ],
    skippedHasMediaNumbers: forced.skippedHasMediaNumbers,
  );
  if (!context.mounted) return combined;
  return showMovieSubscriptionBatchFeedback(
    context,
    combined,
    subscribe: false,
  );
}

class _MovieSubscriptionBatchSkippedContent extends StatelessWidget {
  const _MovieSubscriptionBatchSkippedContent({
    required this.result,
    required this.subscribe,
  });

  final MovieSubscriptionBatchToggleResult result;
  final bool subscribe;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);

    final subtitle = result.updatedCount > 0
        ? (subscribe
              ? l10n.subscriptionBatchSubscribedSkippedSummary(
                  result.updatedCount,
                  result.skippedCount,
                )
              : l10n.subscriptionBatchUnsubscribedSkippedSummary(
                  result.updatedCount,
                  result.skippedCount,
                ))
        : l10n.subscriptionBatchAllSkippedSummary(result.skippedCount);

    // 番号列表用 Flexible + SingleChildScrollView：桌面 dialog 没有固定高度，
    // 内容自然撑到最大；移动 drawer 由 AppBottomDrawerSurface.maxHeightFactor
    // 顶到上限。两端都不会溢出、也不会强撑出无谓空白。
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.subscriptionBatchSkippedTitle,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s18,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.xs),
        Text(
          subtitle,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.lg),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (result.skippedHasMediaNumbers.isNotEmpty)
                  _SkippedNumbersGroup(
                    header: l10n.subscriptionBatchSkippedHasMediaHeader,
                    numbers: result.skippedHasMediaNumbers,
                  ),
                if (result.skippedHasMediaNumbers.isNotEmpty &&
                    result.skippedMovieNotFoundNumbers.isNotEmpty)
                  SizedBox(height: spacing.lg),
                if (result.skippedMovieNotFoundNumbers.isNotEmpty)
                  _SkippedNumbersGroup(
                    header: l10n.subscriptionBatchSkippedNotFoundHeader,
                    numbers: result.skippedMovieNotFoundNumbers,
                  ),
              ],
            ),
          ),
        ),
        if (!subscribe && result.skippedHasMediaNumbers.isNotEmpty) ...[
          SizedBox(height: spacing.lg),
          AppButton(
            key: const Key('movie-batch-force-unsubscribe-button'),
            label: l10n.subscriptionBatchForceDeleteLabel,
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ],
    );
  }
}

/// 一种跳过原因的番号清单：小灰标题 + 番号药丸平铺。
///
/// 番号本身不可点（只是「哪些没处理」的信息），所以刻意不用可点感强的
/// 设置卡行，改用中性 [AppBadge] 药丸——信息密度高、也不暗示可进详情。
class _SkippedNumbersGroup extends StatelessWidget {
  const _SkippedNumbersGroup({required this.header, required this.numbers});

  final String header;
  final List<String> numbers;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$header · ${AppLocalizations.of(context).subscriptionSkippedNumbersCount(numbers.length)}',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(height: spacing.sm),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          children: [
            for (final number in numbers)
              AppBadge(label: number, tone: AppBadgeTone.neutral),
          ],
        ),
      ],
    );
  }
}
