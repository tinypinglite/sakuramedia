import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/format/relative_time_label.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/media_import/data/media_import_api.dart';
import 'package:sakuramedia/features/media_import/presentation/providers/media_import_api_provider.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_list_item_dto.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status.dart';
import 'package:sakuramedia/features/subscriptions/presentation/providers/movie_subscription_manager_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_check_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_left_cover_card.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

/// 订阅管理列表的单行卡片：封面贴左的白卡（[AppLeftCoverCard]），右侧三行信息。
///
/// 信息层次自上而下，一行答一个问题：
/// 1. **这是哪部片**：番号（主）+ 标题（次）+ 右上角状态徽标；
/// 2. **求片走到哪了**：新片 / 剩余没找到次数、上次查询多久以前、试死了几个种子——
///    这一行是整个页面存在的理由，别的影片列表都给不出；已拿到资源的行（下载中 /
///    已入库 / 未入库）不展示查询进度，只保留死种徽标；
/// 3. **背景信息 + 操作**：发行 / 订阅时间靠左，磁力搜索 / 取消订阅靠右。
///
/// `status == failed` 时在 2、3 之间插一行索引器错误详情；未入库行展示导入结果。
///
/// 手势分两态：常规态整卡点击 = 打开影片详情；多选态整卡点击 = 切换选中、行内
/// 操作按钮隐藏。**不做「整卡点击即选中」**——这一页的番号是可点进详情的实体，
/// 把详情入口藏进封面会让人找不到。
class MovieSubscriptionRow extends StatelessWidget {
  const MovieSubscriptionRow({
    super.key,
    required this.item,
    required this.selectionMode,
    required this.isSelected,
    required this.isPending,
    required this.onTap,
    required this.onOpenDownloads,
    required this.onSearchMagnet,
    required this.onOpenImportJob,
    required this.onUnsubscribe,
  });

  final MovieSubscriptionListItemDto item;
  final bool selectionMode;
  final bool isSelected;

  /// 该行有动作在飞：操作按钮换成转圈，避免重复点击。
  final bool isPending;

  /// 常规态 = 打开影片详情；多选态 = 切换选中。由调用方按 [selectionMode] 决定。
  final VoidCallback onTap;

  /// 跳转到任务中心的下载任务视图，并定位到本订阅片对应番号。
  final VoidCallback onOpenDownloads;

  /// 打开此影片的手动磁力搜索弹窗。
  final VoidCallback onSearchMagnet;

  /// 跳转到资源导入中心（import_failed 行查看具体结果与文件）。
  final VoidCallback onOpenImportJob;

  final VoidCallback onUnsubscribe;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;
    final lastError = item.lastError;

    return AppLeftCoverCard(
      key: Key('movie-subscription-row-${item.movieNumber}'),
      coverWidth: componentTokens.subscriptionRowCoverWidth,
      bodyMinHeight: componentTokens.subscriptionRowMinHeight,
      bodyPadding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      selected: selectionMode && isSelected,
      onTap: onTap,
      cover: _CoverSlot(
        item: item,
        selectionMode: selectionMode,
        isSelected: isSelected,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeadingLine(item: item),
          SizedBox(height: spacing.md),
          _SearchProgressLine(item: item),
          if (item.importOperation?.importFailureMessage != null) ...[
            SizedBox(height: spacing.sm),
            _ImportFailureLine(
              item: item,
              message: item.importOperation!.importFailureMessage!,
            ),
          ],
          if (lastError != null && lastError.isNotEmpty) ...[
            SizedBox(height: spacing.sm),
            _LastErrorLine(item: item, message: lastError),
          ],
          SizedBox(height: spacing.sm),
          _FooterLine(
            item: item,
            selectionMode: selectionMode,
            isPending: isPending,
            onOpenDownloads: onOpenDownloads,
            onSearchMagnet: onSearchMagnet,
            onOpenImportJob: onOpenImportJob,
            onUnsubscribe: onUnsubscribe,
          ),
        ],
      ),
    );
  }
}

/// 封面 slot：横版封面铺满裁切；无图时占位。
///
/// 多选态在左上角叠 [SelectionCheckBadge]——未选也显示空心圈，让「现在能勾选」
/// 这件事在每一行上都可见，而不是只在选中后才有反馈。
class _CoverSlot extends StatelessWidget {
  const _CoverSlot({
    required this.item,
    required this.selectionMode,
    required this.isSelected,
  });

  final MovieSubscriptionListItemDto item;
  final bool selectionMode;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final url = item.coverImage?.bestAvailableUrl.trim();
    final Widget image = url != null && url.isNotEmpty
        ? MaskedImage(
            key: Key('movie-subscription-cover-${item.movieNumber}'),
            url: url,
            fit: BoxFit.cover,
          )
        : Container(
            key: Key(
              'movie-subscription-cover-placeholder-${item.movieNumber}',
            ),
            color: context.appColors.surfaceMuted,
            alignment: Alignment.center,
            child: Icon(
              Icons.movie_creation_outlined,
              size: context.appComponentTokens.iconSize2xl,
              color: context.appTextPalette.muted,
            ),
          );

    if (!selectionMode) {
      return image;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        PositionedDirectional(
          top: context.appSpacing.sm,
          start: context.appSpacing.sm,
          child: SelectionCheckBadge(isSelected: isSelected),
        ),
      ],
    );
  }
}

/// 标题行：番号（主）+ 标题（次），右上角贴状态徽标。
///
/// 番号在上、标题在下——这一页的操作单位是番号（重置 / 取消订阅 / 反馈清单都按
/// 番号说话），不是片名。
class _HeadingLine extends StatelessWidget {
  const _HeadingLine({required this.item});

  final MovieSubscriptionListItemDto item;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.movieNumber,
                key: Key('movie-subscription-row-number-${item.movieNumber}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              SizedBox(height: spacing.xs),
              Text(
                item.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: spacing.sm),
        AppBadge(
          key: Key('movie-subscription-row-status-${item.movieNumber}'),
          label: item.displayStatusLabel,
          tone: _statusBadgeTone(item),
          size: AppBadgeSize.compact,
        ),
      ],
    );
  }
}

/// 状态徽标配色。
///
/// 语义分档而不是逐个上色：**出错要人管的**（导入失败 / 查询出错）红，**次数用尽要人
/// 管的**（已放弃）橙，**在进行中的**（下载中 / 待查）信息蓝，**已完成的**（已入库）
/// 成功绿，**还在等的**（缺资源）中性。缺资源刻意留中性——它是默认签、占比最大，
/// 全页染色只会让真正要处理的那几态淹没在色块里。
AppBadgeTone _statusBadgeTone(MovieSubscriptionListItemDto item) {
  if (item.isNoMediaImport) {
    return AppBadgeTone.warning;
  }
  return switch (item.status) {
    MovieSubscriptionStatus.imported => AppBadgeTone.success,
    MovieSubscriptionStatus.importFailed => AppBadgeTone.error,
    MovieSubscriptionStatus.downloading => AppBadgeTone.info,
    MovieSubscriptionStatus.exhausted => AppBadgeTone.warning,
    MovieSubscriptionStatus.failed => AppBadgeTone.error,
    MovieSubscriptionStatus.missing => AppBadgeTone.neutral,
    MovieSubscriptionStatus.pending => AppBadgeTone.info,
    MovieSubscriptionStatus.unknown => AppBadgeTone.neutral,
  };
}

/// 求片进度行：新片 / 放弃倒计时 + 上次查询时间 + 死种数。
///
/// `attempt_count` 的语义是「本轮没找到可用资源的次数」，不是总查询次数：成功找到
/// 资源后后端会把计数清零，所以下载中 / 已入库 / 导入失败这些已经拿到资源的行再
/// 展示「已查 N/M」会误导成「从没查过」。这里按状态收口：
/// - 待查：只显示「尚未查询」（新片加「持续查询中」）；
/// - 缺资源 / 查询出错：剩余没找到额度倒计时「再尝试 N 次就放弃」+ 上次查询时间；
/// - 已放弃：本轮没找到次数已用尽，展示「已查询过 N 次」+ 上次查询时间；
/// - 其余状态：不展示任何查询进度文案，只保留死种徽标。
class _SearchProgressLine extends StatelessWidget {
  const _SearchProgressLine({required this.item});

  final MovieSubscriptionListItemDto item;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final mutedStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.muted,
    );
    final lastSearchedAt = item.lastSearchedAt;
    // 只有还在「找资源」链路里的状态才谈得上查询进度；已拿到资源的行展示次数
    // 只会误导（成功即清零，恒为 0）。
    final showSearchProgress = switch (item.status) {
      MovieSubscriptionStatus.pending ||
      MovieSubscriptionStatus.missing ||
      MovieSubscriptionStatus.failed ||
      MovieSubscriptionStatus.exhausted => true,
      _ => false,
    };

    return Wrap(
      spacing: spacing.sm,
      runSpacing: spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 这些文案都用 muted 文本、不给新片加彩色 badge：它们占同一个槽、答同一个
        // 问题（求片走到哪了），视觉权重就该一样；差异由文字承担。一行里彩色元素
        // 也因此收敛到「状态徽标 + 死种告警」最多两个。
        if (showSearchProgress) ...[
          if (item.isFresh)
            Text(
              '新片 · 持续查询中',
              key: Key('movie-subscription-row-fresh-${item.movieNumber}'),
              style: mutedStyle,
            )
          else if (item.status == MovieSubscriptionStatus.exhausted)
            // 已放弃时计数已攒满上限，倒计时归零没有信息量，直接说已查询过几次。
            Text(
              '已查询过 ${item.attemptCount} 次',
              key: Key('movie-subscription-row-attempts-${item.movieNumber}'),
              style: mutedStyle,
            )
          else if (item.attemptCount > 0 &&
              item.attemptCount < item.attemptLimit)
            Text(
              '再尝试 ${item.attemptLimit - item.attemptCount} 次就放弃',
              key: Key('movie-subscription-row-attempts-${item.movieNumber}'),
              style: mutedStyle,
            ),
          Text(
            lastSearchedAt == null
                ? '尚未查询'
                : formatRelativeTimeLabel(lastSearchedAt, suffix: '查过'),
            style: mutedStyle,
          ),
        ],
        if (item.deadDownloadTaskCount > 0)
          AppBadge(
            key: Key('movie-subscription-row-dead-${item.movieNumber}'),
            label: '${item.deadDownloadTaskCount} 个种子已判死',
            tone: AppBadgeTone.warning,
            size: AppBadgeSize.compact,
          ),
      ],
    );
  }
}

/// 索引器错误详情行（仅 `status == failed`）。
///
/// 单行省略 + Tooltip 看全文：错误原文可能很长，铺开会把整行卡片撑变形，而它对
/// 大多数用户只是「出错了，下轮会自己重试」的注脚。
class _LastErrorLine extends StatelessWidget {
  const _LastErrorLine({required this.item, required this.message});

  final MovieSubscriptionListItemDto item;
  final String message;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final palette = context.appTextPalette;
    return Tooltip(
      message: message,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: context.appComponentTokens.iconSize3xs,
            color: palette.error,
          ),
          SizedBox(width: spacing.xs),
          Expanded(
            child: Text(
              message,
              key: Key('movie-subscription-row-error-${item.movieNumber}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 导入结果行：`import_failed` 档在查询进度与操作之间插一行，直接回答
/// 「文件明明下好了，为什么没进库」。文案来自导入作业摘要，
/// 与 [_LastErrorLine]（索引器查询出错）语义不同，独立成件、独立 Key。
class _ImportFailureLine extends StatelessWidget {
  const _ImportFailureLine({required this.item, required this.message});

  final MovieSubscriptionListItemDto item;
  final String message;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final palette = context.appTextPalette;
    final isNoMedia = item.isNoMediaImport;
    return Tooltip(
      message: message,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            isNoMedia
                ? Icons.warning_amber_rounded
                : Icons.report_gmailerrorred_rounded,
            size: context.appComponentTokens.iconSize3xs,
            color: isNoMedia ? palette.warning : palette.error,
          ),
          SizedBox(width: spacing.xs),
          Expanded(
            child: Text(
              message,
              key: Key(
                'movie-subscription-row-import-error-${item.movieNumber}',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: isNoMedia ? AppTextTone.warning : AppTextTone.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 底行：左侧背景信息（发行 / 订阅 / 本地媒体），右侧行内操作。
class _FooterLine extends StatelessWidget {
  const _FooterLine({
    required this.item,
    required this.selectionMode,
    required this.isPending,
    required this.onOpenDownloads,
    required this.onSearchMagnet,
    required this.onOpenImportJob,
    required this.onUnsubscribe,
  });

  final MovieSubscriptionListItemDto item;
  final bool selectionMode;
  final bool isPending;
  final VoidCallback onOpenDownloads;
  final VoidCallback onSearchMagnet;
  final VoidCallback onOpenImportJob;
  final VoidCallback onUnsubscribe;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final palette = context.appTextPalette;
    final mutedStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.muted,
    );
    final subscribedAt = item.subscribedAt;
    final facts = <String>[
      if (item.releaseDate != null) '发行 ${item.releaseDate}',
      if (subscribedAt != null)
        formatRelativeTimeLabel(subscribedAt, suffix: '订阅'),
      if (item.mediaCount > 0) '本地 ${item.mediaCount} 个媒体',
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.event_outlined,
          size: context.appComponentTokens.iconSize3xs,
          color: palette.muted,
        ),
        SizedBox(width: spacing.xs),
        Expanded(
          child: Text(
            facts.isEmpty ? '暂无发行与订阅信息' : facts.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mutedStyle,
          ),
        ),
        // 多选态收起行内操作：批量动作走顶栏 / 底部条，两套入口并存会让「我这一下
        // 到底改了哪些」变得不可预期。
        if (!selectionMode) ...[
          SizedBox(width: spacing.sm),
          if (isPending)
            const AppInlineSpinner()
          else
            _RowActions(
              item: item,
              onOpenDownloads: onOpenDownloads,
              onSearchMagnet: onSearchMagnet,
              onOpenImportJob: onOpenImportJob,
              onUnsubscribe: onUnsubscribe,
            ),
        ],
      ],
    );
  }
}

class _RowActions extends ConsumerWidget {
  const _RowActions({
    required this.item,
    required this.onOpenDownloads,
    required this.onSearchMagnet,
    required this.onOpenImportJob,
    required this.onUnsubscribe,
  });

  final MovieSubscriptionListItemDto item;
  final VoidCallback onOpenDownloads;
  final VoidCallback onSearchMagnet;
  final VoidCallback onOpenImportJob;
  final VoidCallback onUnsubscribe;

  Future<void> _runImportAction(
    WidgetRef ref, {
    required Future<void> Function(MediaImportApi api) request,
    required String successMessage,
    required String failureMessage,
  }) async {
    try {
      await request(ref.read(mediaImportApiProvider));
      showToast(successMessage);
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: failureMessage));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importOperation = item.status == MovieSubscriptionStatus.importFailed
        ? item.importOperation
        : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 查看下载任务：这部订阅片的资源查询走到哪一步，最终都落到下载记录上。
        // 摆在最左，是对「下载中 / 导入失败」卡片最直接的跟进入口。
        AppIconButton(
          key: Key('movie-subscription-row-downloads-${item.movieNumber}'),
          icon: const Icon(Icons.download_outlined),
          size: AppIconButtonSize.regular,
          tooltip: '查看下载任务',
          semanticLabel: '查看下载任务',
          onPressed: onOpenDownloads,
        ),
        AppIconButton(
          key: Key('movie-subscription-row-magnet-search-${item.movieNumber}'),
          icon: const Icon(Icons.search_rounded),
          size: AppIconButtonSize.regular,
          tooltip: '磁力搜索',
          semanticLabel: '磁力搜索',
          onPressed: onSearchMagnet,
        ),
        // 查看导入作业：失败原因只是摘要，详细 failed_files（含每条路径）在导入中心。
        if (importOperation?.canOpenImportJob ?? false)
          AppIconButton(
            key: Key('movie-subscription-row-open-import-${item.movieNumber}'),
            icon: const Icon(Icons.folder_open_outlined),
            size: AppIconButtonSize.regular,
            tooltip: '查看导入作业 #${importOperation!.importJobId}（失败详情与重导入口）',
            semanticLabel: '查看导入作业',
            onPressed: onOpenImportJob,
          ),
        // 导入补救出口（Wave 4）：按后端 available_actions 渲染，绝不伪造重试按钮。
        if (importOperation != null && importOperation.canRetryFailedFiles)
          AppIconButton(
            key: Key('movie-subscription-row-retry-import-${item.movieNumber}'),
            icon: const Icon(Icons.build_circle_outlined),
            size: AppIconButtonSize.regular,
            tooltip:
                '重导 ${importOperation.retryableFileCount} 个失败文件（作业 #${importOperation.importJobId}）',
            semanticLabel: '重导失败文件',
            onPressed: () => _runImportAction(
              ref,
              request: (api) =>
                  api.retryFailedFiles(importOperation.importJobId),
              successMessage: '重导任务已提交，可在导入中心跟进',
              failureMessage: '提交重导失败',
            ),
          ),
        if (importOperation != null && importOperation.canRerun)
          AppIconButton(
            key: Key('movie-subscription-row-rerun-import-${item.movieNumber}'),
            icon: const Icon(Icons.replay_circle_filled_outlined),
            size: AppIconButtonSize.regular,
            tooltip: importOperation.retryableFileCount > 0
                ? '整作业重跑（作业 #${importOperation.importJobId}）'
                : '上次导入零产出（跳过 ${importOperation.skippedCount} 个文件），整作业重跑一次',
            semanticLabel: '整作业重跑',
            onPressed: () => _runImportAction(
              ref,
              request: (api) => api.rerunImportJob(importOperation.importJobId),
              successMessage: '重跑任务已提交，可在导入中心跟进',
              failureMessage: '提交重跑失败',
            ),
          ),
        // 忽略这条失败记录：复用下载中心的删除任务语义，删掉后本片重新参与
        // 自动下载（下一轮 cron 找新种）。这是「不想要这条记录」的出口，
        // 与重导/重跑（想抢救现有文件）语义相反。
        if (importOperation?.canDeleteFailedDownload ?? false)
          AppIconButton(
            key: Key(
              'movie-subscription-row-delete-download-${item.movieNumber}',
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            size: AppIconButtonSize.regular,
            tooltip: '删除下载记录（本片将重新参与自动下载）',
            semanticLabel: '删除下载记录',
            onPressed: () => _confirmDeleteFailedDownload(context, ref, item),
          ),
        AppIconButton(
          key: Key('movie-subscription-row-unsubscribe-${item.movieNumber}'),
          icon: const Icon(Icons.bookmark_remove_outlined),
          size: AppIconButtonSize.regular,
          tooltip: '取消订阅',
          semanticLabel: '取消订阅',
          onPressed: onUnsubscribe,
        ),
      ],
    );
  }
}

/// 删除 import_failed 关联的失败下载记录（复用下载中心的删除任务语义）。
///
/// 删除后该影片不再有活跃下载任务，订阅状态回到「缺资源」，下一轮自动下载 cron
/// 会重新找种；旧文件是否一起删由用户在确认框里勾选，默认保留。
Future<void> _confirmDeleteFailedDownload(
  BuildContext context,
  WidgetRef ref,
  MovieSubscriptionListItemDto item,
) async {
  final taskId = item.importOperation?.downloadTaskId;
  if (taskId == null) {
    return;
  }
  var deleteFiles = false;
  final confirmed = await showAppConfirmDialog(
    context,
    dialogKey: Key(
      'movie-subscription-delete-download-dialog-${item.movieNumber}',
    ),
    title: '删除下载记录',
    message:
        '确认删除「${item.movieNumber}」的失败下载记录？'
        '删除后本片会重新参与自动下载（每天一轮），导入失败记录不再显示。',
    danger: true,
    confirmLabel: '删除记录',
    failureFallback: '删除下载记录失败',
    extraContent: _DeleteDownloadFilesCheckbox(
      onChanged: (value) => deleteFiles = value,
    ),
    onConfirm: () async {
      await ref
          .read(downloadsApiProvider)
          .deleteDownloadTask(taskId, deleteFiles: deleteFiles);
      await ref.read(movieSubscriptionManagerProvider.notifier).refresh();
    },
  );
  if (confirmed && context.mounted) {
    showToast('已删除下载记录，等待自动下载重新找种');
  }
}

class _DeleteDownloadFilesCheckbox extends StatefulWidget {
  const _DeleteDownloadFilesCheckbox({required this.onChanged});

  final ValueChanged<bool> onChanged;

  @override
  State<_DeleteDownloadFilesCheckbox> createState() =>
      _DeleteDownloadFilesCheckboxState();
}

class _DeleteDownloadFilesCheckboxState
    extends State<_DeleteDownloadFilesCheckbox> {
  bool _checked = false;

  void _toggle(bool value) {
    setState(() => _checked = value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _toggle(!_checked),
      borderRadius: context.appRadius.smBorder,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.appSpacing.xs),
        child: Row(
          children: [
            Checkbox(
              key: const Key('movie-subscription-delete-files-checkbox'),
              value: _checked,
              onChanged: (value) => _toggle(value ?? false),
            ),
            SizedBox(width: context.appSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '同时删除已下载的文件',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.secondary,
                    ),
                  ),
                  SizedBox(height: context.appSpacing.xs / 2),
                  Text(
                    '不影响已导入媒体库的文件',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s10,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
