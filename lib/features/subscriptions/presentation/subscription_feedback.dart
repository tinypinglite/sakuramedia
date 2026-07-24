import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/paged_actor_summary_controller.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/paged_movie_summary_controller.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

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

/// 影片批量订阅/取消订阅结果反馈：
/// - 全成功（无 skip） → 一条 toast；
/// - 请求整体失败 → 一条 toast（错误文案已由 controller 侧转成中文）；
/// - 有 skip → 一条摘要 toast + 弹「未处理清单」按原因分组。
///
/// 未处理清单壳由 [showAppAdaptiveModal] 自动分流：桌面走 [AppDesktopDialog]，
/// 移动走 [AppBottomDrawer]。内容是轻量反馈语言——每种跳过原因一个小灰标题 +
/// 一排 [AppBadge] 番号药丸，不套设置页分组卡（番号不可点，用卡壳会误导）。
Future<void> showMovieSubscriptionBatchFeedback(
  BuildContext context,
  MovieSubscriptionBatchToggleResult result, {
  required bool subscribe,
}) async {
  final actionVerb = subscribe ? '订阅' : '取消订阅';

  if (result.hasError) {
    showToast(result.errorMessage ?? (subscribe ? '批量订阅影片失败' : '批量取消订阅影片失败'));
    return;
  }

  if (result.skippedCount == 0) {
    if (result.updatedCount == 0) {
      // 请求成功但无有效变更（例如全部已是目标态），静默不打扰。
      return;
    }
    showToast('已$actionVerb ${result.updatedCount} 部影片');
    return;
  }

  if (result.updatedCount > 0) {
    showToast(
      '已$actionVerb ${result.updatedCount} 部，${result.skippedCount} 部未处理',
    );
  } else {
    showToast('${result.skippedCount} 部影片未处理');
  }

  if (!context.mounted) {
    return;
  }

  await showAppAdaptiveModal<void>(
    context: context,
    modalKey: const Key('movie-list-batch-skipped-modal'),
    // 桌面：番号药丸窄内容，小号对话框宽度足够；抽屉走默认 heightFactor（0.9）。
    desktopWidth: context.appLayoutTokens.dialogWidthSm,
    mobileMaxHeightFactor: 0.85,
    builder:
        (_) => _MovieSubscriptionBatchSkippedContent(
          result: result,
          subscribe: subscribe,
        ),
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
    final actionVerb = subscribe ? '订阅' : '取消订阅';

    final subtitle =
        result.updatedCount > 0
            ? '已$actionVerb ${result.updatedCount} 部，剩余 ${result.skippedCount} 部因下列原因未处理'
            : '${result.skippedCount} 部影片因下列原因未处理';

    // 番号列表用 Flexible + SingleChildScrollView：桌面 dialog 没有固定高度，
    // 内容自然撑到最大；移动 drawer 由 AppBottomDrawerSurface.maxHeightFactor
    // 顶到上限。两端都不会溢出、也不会强撑出无谓空白。
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '部分影片未处理',
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
                    header: '已存在媒体，无法取消订阅',
                    numbers: result.skippedHasMediaNumbers,
                  ),
                if (result.skippedHasMediaNumbers.isNotEmpty &&
                    result.skippedMovieNotFoundNumbers.isNotEmpty)
                  SizedBox(height: spacing.lg),
                if (result.skippedMovieNotFoundNumbers.isNotEmpty)
                  _SkippedNumbersGroup(
                    header: '库中无此番号',
                    numbers: result.skippedMovieNotFoundNumbers,
                  ),
              ],
            ),
          ),
        ),
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
          '$header · ${numbers.length} 部',
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
