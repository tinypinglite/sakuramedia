import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_toggle_result.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';

/// 影片批量订阅/取消订阅的执行闭包：由调用方绑定到具体分页控制器的
/// `batchToggleSubscription` 方法。这样 helper 无需知道 controller 具体类型
/// （`PagedMovieSummaryController` 与 `PagedRankedMovieController` 都可用）。
typedef MovieBatchToggleExecutor =
    Future<MovieSubscriptionBatchToggleResult> Function({
      required Iterable<String> movieNumbers,
      required bool subscribe,
    });

typedef MovieBlacklistBatchExecutor =
    Future<void> Function({required Iterable<String> movieNumbers});

/// 批量动作种类，用于区分「哪个按钮该转圈」。
enum MovieBatchAction { subscribe, unsubscribe, blacklist }

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
    final l10n = AppLocalizations.of(context);
    return AppMobileSelectionHeader(
      selectionLabel: l10n.widgetMovieSelectionCount(selectedCount),
      exitKey: Key('$keyPrefix-exit-selection-button'),
      onExitSelection: onExit,
      selectAllKey: Key('$keyPrefix-select-all-button'),
      selectAllTooltip: allSelected
          ? l10n.widgetMovieDeselectAll
          : l10n.widgetMovieSelectAllWithCount(visibleTotal),
      onToggleAll: onToggleAll,
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
    this.onBlacklist,
  });

  final String keyPrefix;
  final MovieBatchAction? operatingAction;
  final VoidCallback? onSubscribe;
  final VoidCallback? onUnsubscribe;
  final VoidCallback? onBlacklist;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppSelectionBottomBar(
      key: Key('$keyPrefix-batch-bottom-bar'),
      actions: [
        AppButton(
          key: Key('$keyPrefix-batch-subscribe-button'),
          label: l10n.widgetMovieSubscribe,
          variant: AppButtonVariant.primary,
          isLoading: operatingAction == MovieBatchAction.subscribe,
          onPressed: onSubscribe,
        ),
        AppButton(
          key: Key('$keyPrefix-batch-unsubscribe-button'),
          label: l10n.widgetMovieUnsubscribe,
          variant: AppButtonVariant.danger,
          isLoading: operatingAction == MovieBatchAction.unsubscribe,
          onPressed: onUnsubscribe,
        ),
        if (onBlacklist != null)
          AppButton(
            key: Key('$keyPrefix-batch-blacklist-button'),
            label: l10n.widgetMovieBlacklist,
            variant: AppButtonVariant.danger,
            isLoading: operatingAction == MovieBatchAction.blacklist,
            onPressed: onBlacklist,
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
  final l10n = AppLocalizations.of(context);
  final actionVerb = subscribe
      ? l10n.widgetMovieSubscribe
      : l10n.widgetMovieUnsubscribe;
  final message = subscribe
      ? l10n.widgetMovieBatchSubscribeMessage(numbers.length)
      : l10n.widgetMovieBatchUnsubscribeMessage(numbers.length);
  final action = subscribe ? 'subscribe' : 'unsubscribe';
  MovieSubscriptionBatchToggleResult? result;
  final confirmed = await showAppConfirmDialog(
    context,
    title: subscribe
        ? l10n.widgetMovieBatchSubscribeTitle
        : l10n.widgetMovieBatchUnsubscribeTitle,
    message: message,
    confirmLabel: actionVerb,
    dialogKey: Key('$keyPrefix-batch-$action-dialog'),
    confirmKey: Key('$keyPrefix-batch-$action-confirm'),
    failureFallback: subscribe
        ? l10n.widgetMovieBatchSubscribeFailed
        : l10n.widgetMovieBatchUnsubscribeFailed,
    onConfirm: () async {
      result = await execute(movieNumbers: numbers, subscribe: subscribe);
    },
  );

  final batchResult = result;
  if (!confirmed || batchResult == null) {
    return null;
  }
  if (context.mounted) {
    return showMovieSubscriptionBatchFeedback(
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
/// build 里 `selectionMode ? buildGlassBatchSelectionToolbar() : <常规 header +
/// buildEnterSelectionButton()>`。
mixin MovieBatchSelectionMixin<W extends StatefulWidget>
    on MultiSelectStateMixin<W, String> {
  MovieBatchAction? _operatingAction;

  /// 批量请求进行中：工具条据此禁用退出/全选。
  bool get isBatchOperating => _operatingAction != null;

  /// 页面/子域前缀，用来生成稳定 Widget Key（如 `movie-list`、`desktop-rankings`）。
  String get batchKeyPrefix;

  /// 绑定到本页分页控制器的 `batchToggleSubscription`。
  MovieBatchToggleExecutor get batchSubscriptionExecutor;

  MovieBlacklistBatchExecutor? get batchBlacklistExecutor => null;

  /// 当前可见（即「全选」覆盖范围）的番号列表。
  List<String> get batchSelectableNumbers;

  /// 批量订阅/取消订阅：确认 → 执行 → 反馈；全成功退出多选，部分成功则只保留
  /// 被跳过的番号仍选中，方便用户二次处理。
  Future<void> runSubscriptionBatch({required bool subscribe}) async {
    if (isBatchOperating || selectedIds.isEmpty) {
      return;
    }
    setState(
      () => _operatingAction = subscribe
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

  Future<void> runBlacklistBatch() async {
    final execute = batchBlacklistExecutor;
    if (execute == null || isBatchOperating || selectedIds.isEmpty) {
      return;
    }
    setState(() => _operatingAction = MovieBatchAction.blacklist);
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.widgetMovieBatchBlacklistTitle,
      message: l10n.widgetMovieBatchBlacklistMessage,
      confirmLabel: l10n.widgetMovieBlacklist,
      danger: true,
      dialogKey: Key('$batchKeyPrefix-batch-blacklist-dialog'),
      confirmKey: Key('$batchKeyPrefix-batch-blacklist-confirm'),
      failureFallback: l10n.widgetMovieBatchBlacklistFailed,
      onConfirm: () => execute(movieNumbers: selectedIds),
    );
    if (!mounted) {
      return;
    }
    setState(() => _operatingAction = null);
    if (confirmed) {
      exitSelection();
    }
  }

  /// 桌面多选态下的玻璃操作条。
  Widget buildGlassBatchSelectionToolbar() {
    final visible = batchSelectableNumbers;
    final busy = isBatchOperating;
    final blacklist = batchBlacklistExecutor;
    final l10n = AppLocalizations.of(context);
    final danger = context.appTextPalette.error;
    final accent = context.appTextPalette.accent;
    return AppGlassSelectionHeader(
      selectionLabel: l10n.widgetMovieSelectionCount(selectedCount),
      countKey: Key('$batchKeyPrefix-selection-count-text'),
      selectAllLabel: isAllSelected(visible)
          ? l10n.widgetMovieDeselectAll
          : l10n.widgetMovieSelectAllWithCount(visible.length),
      selectAllKey: Key('$batchKeyPrefix-select-all-button'),
      onToggleAll: (busy || visible.isEmpty)
          ? null
          : () => toggleSelectAll(visible),
      exitKey: Key('$batchKeyPrefix-exit-selection-button'),
      onExitSelection: busy ? null : exitSelection,
      actions: <AppGlassSelectionAction>[
        AppGlassSelectionAction(
          key: Key('$batchKeyPrefix-batch-subscribe-button'),
          label: l10n.widgetMovieSubscribe,
          icon: Icons.add_circle_outline,
          foregroundColor: accent,
          onTap: (selectedIds.isEmpty || busy)
              ? null
              : () => runSubscriptionBatch(subscribe: true),
        ),
        AppGlassSelectionAction(
          key: Key('$batchKeyPrefix-batch-unsubscribe-button'),
          label: l10n.widgetMovieUnsubscribe,
          icon: Icons.remove_circle_outline,
          foregroundColor: danger,
          onTap: (selectedIds.isEmpty || busy)
              ? null
              : () => runSubscriptionBatch(subscribe: false),
        ),
        if (blacklist != null)
          AppGlassSelectionAction(
            key: Key('$batchKeyPrefix-batch-blacklist-button'),
            label: l10n.widgetMovieBlacklist,
            icon: Icons.block_rounded,
            foregroundColor: danger,
            onTap: (selectedIds.isEmpty || busy) ? null : runBlacklistBatch,
          ),
      ],
    );
  }

  /// 移动端多选态下原地替换为紧凑玻璃多选头（退出 + 计数 + 全选）。
  /// 批量动作另见 [buildMobileBatchSelectionBottomBar]。
  Widget buildMobileBatchSelectionHeader() {
    final visible = batchSelectableNumbers;
    final busy = isBatchOperating;
    return MovieBatchMobileSelectionHeader(
      keyPrefix: batchKeyPrefix,
      selectedCount: selectedCount,
      visibleTotal: visible.length,
      allSelected: isAllSelected(visible),
      onToggleAll: (busy || visible.isEmpty)
          ? null
          : () => toggleSelectAll(visible),
      onExit: busy ? null : exitSelection,
    );
  }

  /// 移动端多选态贴底的批量动作条。
  Widget buildMobileBatchSelectionBottomBar() {
    final busy = isBatchOperating;
    final blacklist = batchBlacklistExecutor;
    return MovieBatchMobileSelectionBottomBar(
      keyPrefix: batchKeyPrefix,
      operatingAction: _operatingAction,
      onSubscribe: (selectedIds.isEmpty || busy)
          ? null
          : () => runSubscriptionBatch(subscribe: true),
      onUnsubscribe: (selectedIds.isEmpty || busy)
          ? null
          : () => runSubscriptionBatch(subscribe: false),
      onBlacklist: (blacklist == null || selectedIds.isEmpty || busy)
          ? null
          : runBlacklistBatch,
    );
  }
}
