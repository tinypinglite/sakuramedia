import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_toolbar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';

/// 影片批量订阅/取消订阅的执行闭包：由调用方绑定到具体分页控制器的
/// `batchToggleSubscription` 方法。这样 helper 无需知道 controller 具体类型
/// （`PagedMovieSummaryController` 与 `PagedRankedMovieController` 都可用）。
typedef MovieBatchToggleExecutor =
    Future<MovieSubscriptionBatchToggleResult> Function({
      required Iterable<String> movieNumbers,
      required bool subscribe,
    });

/// 批量动作种类，用于区分「哪个按钮该转圈」。
enum MovieBatchAction { subscribe, unsubscribe }

/// 影片列表的「进入多选」按钮：[AppSelectionEntryButton] 的薄壳，只负责按
/// [keyPrefix] 生成稳定 Key。列表为空时禁用。
class MovieBatchEnterSelectionButton extends StatelessWidget {
  const MovieBatchEnterSelectionButton({
    super.key,
    required this.keyPrefix,
    required this.enabled,
    required this.onEnter,
  });

  /// 页面/子域前缀，用来生成稳定 Widget Key（如 `movie-list`、`actor-detail`）。
  final String keyPrefix;
  final bool enabled;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    return AppSelectionEntryButton(
      key: Key('$keyPrefix-enter-selection-button'),
      onPressed: enabled ? onEnter : null,
    );
  }
}

/// 影片列表多选态操作条：[AppSelectionToolbar] 的薄壳，往 `actions` 里塞
/// 「订阅」/「取消订阅」两个批量按钮。
class MovieBatchSelectionToolbar extends StatelessWidget {
  const MovieBatchSelectionToolbar({
    super.key,
    required this.keyPrefix,
    required this.selectedCount,
    required this.visibleTotal,
    required this.allSelected,
    required this.operatingAction,
    required this.onToggleAll,
    required this.onSubscribe,
    required this.onUnsubscribe,
    required this.onExit,
  });

  final String keyPrefix;
  final int selectedCount;
  final int visibleTotal;
  final bool allSelected;

  /// 正在提交的批量动作；`null` 表示空闲。只有对应那一个按钮转圈，
  /// 另一个只是禁用——两个都转圈会让用户以为点错了动作。
  final MovieBatchAction? operatingAction;

  /// 「全选/取消全选」按钮回调；`null` 时按钮禁用。
  final VoidCallback? onToggleAll;

  /// 「订阅」批量按钮回调；`null` 时按钮禁用（无选中或正在提交）。
  final VoidCallback? onSubscribe;

  /// 「取消订阅」批量按钮回调；同上。
  final VoidCallback? onUnsubscribe;

  /// 「取消」（退出多选）按钮回调；正在提交时禁用。
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    // 顶栏高度对齐、原地改写筛选行的规则都在 AppSelectionHeaderToolbar 里，
    // 这里只负责塞影片特有的两个批量动作。
    return AppSelectionHeaderToolbar(
      countLabel: '已选 $selectedCount 部',
      countKey: Key('$keyPrefix-selection-count-text'),
      selectAllLabel: allSelected ? '取消全选' : '全选($visibleTotal)',
      selectAllKey: Key('$keyPrefix-select-all-button'),
      onToggleAll: onToggleAll,
      actions: [
        AppButton(
          key: Key('$keyPrefix-batch-subscribe-button'),
          label: '订阅',
          variant: AppButtonVariant.primary,
          size: AppButtonSize.small,
          isLoading: operatingAction == MovieBatchAction.subscribe,
          onPressed: onSubscribe,
        ),
        AppButton(
          key: Key('$keyPrefix-batch-unsubscribe-button'),
          label: '取消订阅',
          variant: AppButtonVariant.danger,
          size: AppButtonSize.small,
          isLoading: operatingAction == MovieBatchAction.unsubscribe,
          onPressed: onUnsubscribe,
        ),
      ],
      exitKey: Key('$keyPrefix-exit-selection-button'),
      onExit: onExit,
    );
  }
}

/// 移动端影片列表多选态**顶栏**：退出 + 计数 + 全选，仅此三样。
///
/// 真正的批量动作在 [MovieBatchMobileSelectionBottomBar]——顶栏只承载「我现在
/// 选了几个、要不要全选、怎么退出」这类上下文，避免危险动作和退出按钮挤在同
/// 一处误触，也让动作落到拇指够得到的屏幕底部。
class MovieBatchMobileSelectionHeader extends StatelessWidget {
  const MovieBatchMobileSelectionHeader({
    super.key,
    required this.keyPrefix,
    required this.selectedCount,
    required this.visibleTotal,
    required this.allSelected,
    required this.onToggleAll,
    required this.onExit,
  });

  final String keyPrefix;
  final int selectedCount;
  final int visibleTotal;
  final bool allSelected;
  final VoidCallback? onToggleAll;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    return AppListHeader.selection(
      selectionLabel: '已选 $selectedCount 部',
      selectionExitButtonKey: Key('$keyPrefix-exit-selection-button'),
      onExitSelection: onExit,
      actionSlots: [
        AppButton(
          key: Key('$keyPrefix-select-all-button'),
          label: allSelected ? '取消全选' : '全选($visibleTotal)',
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.xSmall,
          isSelected: allSelected,
          onPressed: onToggleAll,
        ),
      ],
    );
  }
}

/// 移动端影片列表多选态**底部**批量动作条：订阅 / 取消订阅等宽平分。
class MovieBatchMobileSelectionBottomBar extends StatelessWidget {
  const MovieBatchMobileSelectionBottomBar({
    super.key,
    required this.keyPrefix,
    required this.operatingAction,
    required this.onSubscribe,
    required this.onUnsubscribe,
  });

  final String keyPrefix;
  final MovieBatchAction? operatingAction;
  final VoidCallback? onSubscribe;
  final VoidCallback? onUnsubscribe;

  @override
  Widget build(BuildContext context) {
    return AppSelectionBottomBar(
      key: Key('$keyPrefix-batch-bottom-bar'),
      actions: [
        AppButton(
          key: Key('$keyPrefix-batch-subscribe-button'),
          label: '订阅',
          variant: AppButtonVariant.primary,
          isLoading: operatingAction == MovieBatchAction.subscribe,
          onPressed: onSubscribe,
        ),
        AppButton(
          key: Key('$keyPrefix-batch-unsubscribe-button'),
          label: '取消订阅',
          variant: AppButtonVariant.danger,
          isLoading: operatingAction == MovieBatchAction.unsubscribe,
          onPressed: onUnsubscribe,
        ),
      ],
    );
  }
}

/// 影片批量订阅/取消订阅的统一入口：弹确认对话框 → 调 controller 批量方法 →
/// 显示 toast/未处理抽屉；返回 controller 侧结果（用户取消或入参为空返回 `null`）。
///
/// 调用方拿到非 null 结果后自己决定：
/// - `result.hasError`：请求整体失败，通常保留选择状态让用户重试；
/// - `result.skippedCount == 0`：全成功，通常 `exitSelection()`；
/// - 否则：部分成功，保留 `result.allSkippedNumbers` 仍选中以便二次处理。
Future<MovieSubscriptionBatchToggleResult?> runMovieSubscriptionBatch({
  required BuildContext context,
  required MovieBatchToggleExecutor execute,
  required Iterable<String> movieNumbers,
  required bool subscribe,
  required String keyPrefix,
}) async {
  final numbers = movieNumbers.toList(growable: false);
  if (numbers.isEmpty) {
    return null;
  }
  final actionVerb = subscribe ? '订阅' : '取消订阅';
  final message =
      subscribe
          ? '将订阅选中的 ${numbers.length} 部影片。'
          : '将取消选中的 ${numbers.length} 部影片的订阅，存在本地媒体的影片会自动跳过。';
  final action = subscribe ? 'subscribe' : 'unsubscribe';
  MovieSubscriptionBatchToggleResult? result;
  final confirmed = await showAppConfirmDialog(
    context,
    title: '批量$actionVerb',
    message: message,
    confirmLabel: actionVerb,
    dialogKey: Key('$keyPrefix-batch-$action-dialog'),
    confirmKey: Key('$keyPrefix-batch-$action-confirm'),
    failureFallback: '批量$actionVerb失败',
    onConfirm: () async {
      result = await execute(movieNumbers: numbers, subscribe: subscribe);
    },
  );

  final batchResult = result;
  if (!confirmed || batchResult == null) {
    return null;
  }
  if (context.mounted) {
    await showMovieSubscriptionBatchFeedback(
      context,
      batchResult,
      subscribe: subscribe,
    );
  }
  return batchResult;
}

/// 影片列表页的「批量订阅多选态」页面级能力：提交中标志 + 批量执行 + 两个工具件
/// 的组装，收敛此前 7 个宿主页逐字重复的 `_isBatchOperating` / `_runBatch` /
/// `_buildBatchSelectionToolbar`。
///
/// 宿主 State 用法（`with` 顺序必须 [MultiSelectStateMixin] 在前，本 mixin 在后）：
/// ```dart
/// class _XxxPageState extends State<XxxPage>
///     with MultiSelectStateMixin<XxxPage, String>, MovieBatchSelectionMixin<XxxPage> {
///   @override
///   String get batchKeyPrefix => 'xxx';
///   @override
///   MovieBatchToggleExecutor get batchSubscriptionExecutor =>
///       _controller.batchToggleSubscription;
///   @override
///   List<String> get batchSelectableNumbers =>
///       _controller.items.map((movie) => movie.movieNumber).toList(growable: false);
/// }
/// ```
/// build 里 `selectionMode ? buildBatchSelectionToolbar() : <常规 header +
/// buildEnterSelectionButton()>`。
mixin MovieBatchSelectionMixin<W extends StatefulWidget>
    on MultiSelectStateMixin<W, String> {
  MovieBatchAction? _operatingAction;

  /// 正在提交的批量动作；`null` 表示空闲。
  MovieBatchAction? get operatingBatchAction => _operatingAction;

  /// 批量请求进行中：工具条据此禁用退出/全选。
  bool get isBatchOperating => _operatingAction != null;

  /// 页面/子域前缀，用来生成稳定 Widget Key（如 `movie-list`、`desktop-rankings`）。
  String get batchKeyPrefix;

  /// 绑定到本页分页控制器的 `batchToggleSubscription`。
  MovieBatchToggleExecutor get batchSubscriptionExecutor;

  /// 当前可见（即「全选」覆盖范围）的番号列表。
  List<String> get batchSelectableNumbers;

  /// 批量订阅/取消订阅：确认 → 执行 → 反馈；全成功退出多选，部分成功则只保留
  /// 被跳过的番号仍选中，方便用户二次处理。
  Future<void> runSubscriptionBatch({required bool subscribe}) async {
    if (isBatchOperating || selectedIds.isEmpty) {
      return;
    }
    setState(
      () =>
          _operatingAction =
              subscribe
                  ? MovieBatchAction.subscribe
                  : MovieBatchAction.unsubscribe,
    );
    final result = await runMovieSubscriptionBatch(
      context: context,
      execute: batchSubscriptionExecutor,
      movieNumbers: selectedIds,
      subscribe: subscribe,
      keyPrefix: batchKeyPrefix,
    );
    if (!mounted) {
      return;
    }
    setState(() => _operatingAction = null);
    if (result == null || result.hasError) {
      return;
    }
    if (result.skippedCount == 0) {
      exitSelection();
    } else {
      final skippedSet = result.allSkippedNumbers.toSet();
      setState(() {
        selectedIds
          ..clear()
          ..addAll(skippedSet);
      });
    }
  }

  /// 多选态下原地替换筛选行的操作条。
  Widget buildBatchSelectionToolbar() {
    final visible = batchSelectableNumbers;
    final busy = isBatchOperating;
    return MovieBatchSelectionToolbar(
      keyPrefix: batchKeyPrefix,
      selectedCount: selectedCount,
      visibleTotal: visible.length,
      allSelected: isAllSelected(visible),
      operatingAction: _operatingAction,
      onToggleAll:
          (busy || visible.isEmpty) ? null : () => toggleSelectAll(visible),
      onSubscribe:
          (selectedIds.isEmpty || busy)
              ? null
              : () => runSubscriptionBatch(subscribe: true),
      onUnsubscribe:
          (selectedIds.isEmpty || busy)
              ? null
              : () => runSubscriptionBatch(subscribe: false),
      onExit: busy ? null : exitSelection,
    );
  }

  /// 移动端多选态下原地替换 [AppListHeader]（退出 + 计数 + 全选）。
  /// 批量动作另见 [buildMobileBatchSelectionBottomBar]。
  Widget buildMobileBatchSelectionHeader() {
    final visible = batchSelectableNumbers;
    final busy = isBatchOperating;
    return MovieBatchMobileSelectionHeader(
      keyPrefix: batchKeyPrefix,
      selectedCount: selectedCount,
      visibleTotal: visible.length,
      allSelected: isAllSelected(visible),
      onToggleAll:
          (busy || visible.isEmpty) ? null : () => toggleSelectAll(visible),
      onExit: busy ? null : exitSelection,
    );
  }

  /// 移动端多选态贴底的批量动作条。
  Widget buildMobileBatchSelectionBottomBar() {
    final busy = isBatchOperating;
    return MovieBatchMobileSelectionBottomBar(
      keyPrefix: batchKeyPrefix,
      operatingAction: _operatingAction,
      onSubscribe:
          (selectedIds.isEmpty || busy)
              ? null
              : () => runSubscriptionBatch(subscribe: true),
      onUnsubscribe:
          (selectedIds.isEmpty || busy)
              ? null
              : () => runSubscriptionBatch(subscribe: false),
    );
  }

  /// 非多选态下的「选择」入口按钮。
  Widget buildEnterSelectionButton() {
    return MovieBatchEnterSelectionButton(
      keyPrefix: batchKeyPrefix,
      enabled: batchSelectableNumbers.isNotEmpty,
      onEnter: enterSelection,
    );
  }
}
