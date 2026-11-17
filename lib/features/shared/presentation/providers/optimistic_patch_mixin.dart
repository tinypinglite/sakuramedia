import 'package:riverpod_annotation/riverpod_annotation.dart';

/// 批量乐观更新 + 回滚的结果，业务侧决定广播与文案：
/// - [accepted]：请求发出且后端接受（未在 skipped 里）的 key 集。
/// - [skipped]：后端拒绝、已被精准回滚的 key 集。
/// - [errorMessage]：请求整体失败（网络/5xx/…）时的中文错误消息；非空时
///   全部乐观改动已整体回滚，[accepted] / [skipped] 均为空集。
class BatchOptimisticResult<K> {
  const BatchOptimisticResult({
    required this.accepted,
    required this.skipped,
    this.errorMessage,
  });

  factory BatchOptimisticResult.empty() =>
      BatchOptimisticResult<K>(accepted: <K>{}, skipped: <K>{});

  final Set<K> accepted;
  final Set<K> skipped;
  final String? errorMessage;

  bool get isFullSuccess => errorMessage == null && skipped.isEmpty;
  bool get isPartialSuccess => errorMessage == null && skipped.isNotEmpty;
  bool get isTotalFailure => errorMessage != null;
}

/// 乐观更新 + 回滚 mixin：把「先本地立即变 → await API → 失败/部分拒绝回滚」
/// 收敛成两个入口——单条与批量语义不同，拆开（对应 legacy
/// `MovieSubscribableListMixin.toggleSubscription`（in-flight + 成功后 flip，
/// 非乐观）与 `batchToggleSubscription`（先本地 → API → skipped 精准回滚）的
/// 迁移目标形态）。
///
/// 约定：
/// - [withOptimisticPatch]：单条。本地立即应用 [apply] → await [action] →
///   失败恢复原态（整体回滚）并 rethrow。同一 key 已在 in-flight 时短路返回
///   [duplicateResult]（业务传 `ignored` 之类的结果）。
/// - [withBatchOptimisticPatch]：批量。去重后乐观应用 [apply]（对命中项）→
///   await [action] → 成功时按 `skippedFromResult` 精准回滚 skipped 项；请求
///   整体失败则全部回滚并置 [BatchOptimisticResult.errorMessage]。是否「已达
///   目标态不广播」由调用方按自己业务语义过滤（mixin 不知道目标态长什么样）。
/// - State 尚未 build 完成（`state.value == null`）时跳过本地补丁/回滚（无本地
///   态可打），请求照常发出，结果照常返回。
///
/// 四条语义必须对齐 UI 与广播方，迁移前逐条过：
/// 1. **单条 API 是真正乐观**：先本地立即变 → await → 失败整体回滚。in-flight
///    期间局部态已变，UI 需要想清楚这段窗口期的呈现（按钮态 / 列表勾选），
///    不是「点完才变」。
/// 2. **`isInFlight` 与 batch 交叉**：`_inFlight` 只由单条 API 占据，batch 不占。
///    UI 依赖 [isInFlight] 禁按钮时，batch 期间的禁用集合由业务方自己维护
///    （按 keys 记集合，batch 结束清空）。
/// 3. **整体失败的 rollback 语义**：整体失败时以「apply 之前的 original」还原，
///    会 wipe 掉 in-flight 期间其它来源对 state 的并发修改。需要外科式撤销
///    （保留并发修改）时，业务方在 rollback 闭包里按 key 从 original 取值
///    恢复，而不是直接返回 original。
/// 4. **「已达目标态不广播」责任下推**：抽象层不做过滤，业务方用
///    `result.accepted.intersection(patchedKeys)` 过滤要广播的 key（patchedKeys
///    在 apply 闭包里自行收集，参照本仓库测试范式）。
mixin OptimisticPatchMixin<S extends Object> on $AsyncNotifier<S> {
  final Set<Object> _inFlight = <Object>{};

  /// 宿主若有异步 dispose 守卫可覆写为 `true`，阻止请求迟到后写回已销毁的
  /// provider。默认 `false` 保持既有独立 Notifier 的使用方式不变。
  bool get isOptimisticPatchDisposed => false;

  /// 该 key 是否正处于一次 in-flight 操作中。
  bool isInFlight(Object key) => _inFlight.contains(key);

  /// 单条乐观更新：本地立即变 → await [action] → 失败恢复原态并 rethrow。
  ///
  /// 同一 key 已在 in-flight 时短路，返回 [duplicateResult]（默认 null）。
  /// 成功后**不**自动恢复原态——apply 的结果就是最终态。
  Future<R?> withOptimisticPatch<R>({
    required Object key,
    required S Function(S current) apply,
    required Future<R> Function() action,
    R? duplicateResult,
  }) async {
    if (!_inFlight.add(key)) {
      return duplicateResult;
    }
    final original = state.value;
    try {
      if (original != null) {
        state = AsyncData(apply(original));
      }
      return await action();
    } catch (error) {
      if (!isOptimisticPatchDisposed &&
          original != null &&
          state.value != null) {
        state = AsyncData(original);
      }
      rethrow;
    } finally {
      _inFlight.remove(key);
    }
  }

  /// 批量乐观更新：去重后乐观应用 [apply]（对 [keys] 的命中项）→ await
  /// [action]（接收去重后的 key 集）→ 成功时按 `skippedFromResult(result)`
  /// **精准回滚** skipped 项；请求整体失败**或 [apply] 抛出**则全部回滚并返回
  /// [BatchOptimisticResult.isTotalFailure] 的结果（[errorMessageOf] 负责把
  /// 异常转成给用户看的文案，默认 `error.toString()`）——与单条语义对称，
  /// 异常不冒到调用方。
  ///
  /// [rollback] 同时拿到「回滚时刻的 current」与「apply 之前的 original」：
  /// 业务按 key 把值恢复成 original 里的旧值（只回滚真正被改过的项，
  /// 「已达目标态没打补丁」的项天然不动）。
  ///
  /// 空 key 集短路：不调 [action]、不动 state，直接返回空结果。
  Future<BatchOptimisticResult<K>> withBatchOptimisticPatch<K, R>({
    required Iterable<K> keys,
    required S Function(S current, Set<K> applyingKeys) apply,
    required Future<R> Function(Set<K> keys) action,
    required Set<K> Function(R result) skippedFromResult,
    required S Function(S current, S original, Set<K> rollbackKeys) rollback,
    String? Function(Object error)? errorMessageOf,
  }) async {
    final ordered = <K>[];
    final seen = <K>{};
    for (final key in keys) {
      if (seen.add(key)) {
        ordered.add(key);
      }
    }
    if (ordered.isEmpty) {
      return BatchOptimisticResult<K>.empty();
    }
    final applyingKeys = <K>{...ordered};

    final original = state.value;
    final R result;
    try {
      if (original != null) {
        state = AsyncData(apply(original, applyingKeys));
      }
      result = await action(applyingKeys);
    } catch (error) {
      if (!isOptimisticPatchDisposed &&
          original != null &&
          state.value != null) {
        state = AsyncData(rollback(original, original, applyingKeys));
      }
      return BatchOptimisticResult<K>(
        accepted: <K>{},
        skipped: <K>{},
        errorMessage: errorMessageOf?.call(error) ?? error.toString(),
      );
    }

    final skipped = skippedFromResult(result);
    if (!isOptimisticPatchDisposed &&
        skipped.isNotEmpty &&
        original != null &&
        state.value != null) {
      state = AsyncData(rollback(state.value!, original, skipped));
    }
    return BatchOptimisticResult<K>(
      accepted: applyingKeys.difference(skipped),
      skipped: skipped,
    );
  }
}
