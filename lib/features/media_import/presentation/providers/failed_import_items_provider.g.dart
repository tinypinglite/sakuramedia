// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'failed_import_items_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 某个导入任务运行记录的失败文件列表。
///
/// 弹层打开期间由承载组件按 3 秒节奏 invalidate，用于把「重试中」条目推进到
/// 已解决/待处理。

@ProviderFor(failedImportItems)
final failedImportItemsProvider = FailedImportItemsFamily._();

/// 某个导入任务运行记录的失败文件列表。
///
/// 弹层打开期间由承载组件按 3 秒节奏 invalidate，用于把「重试中」条目推进到
/// 已解决/待处理。

final class FailedImportItemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ImportFailedItemDto>>,
          List<ImportFailedItemDto>,
          FutureOr<List<ImportFailedItemDto>>
        >
    with
        $FutureModifier<List<ImportFailedItemDto>>,
        $FutureProvider<List<ImportFailedItemDto>> {
  /// 某个导入任务运行记录的失败文件列表。
  ///
  /// 弹层打开期间由承载组件按 3 秒节奏 invalidate，用于把「重试中」条目推进到
  /// 已解决/待处理。
  FailedImportItemsProvider._({
    required FailedImportItemsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'failedImportItemsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$failedImportItemsHash();

  @override
  String toString() {
    return r'failedImportItemsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ImportFailedItemDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ImportFailedItemDto>> create(Ref ref) {
    final argument = this.argument as int;
    return failedImportItems(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FailedImportItemsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$failedImportItemsHash() => r'360b1cd45344506d877d1fc6ddadaa8bdf2ccebb';

/// 某个导入任务运行记录的失败文件列表。
///
/// 弹层打开期间由承载组件按 3 秒节奏 invalidate，用于把「重试中」条目推进到
/// 已解决/待处理。

final class FailedImportItemsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ImportFailedItemDto>>, int> {
  FailedImportItemsFamily._()
    : super(
        retry: null,
        name: r'failedImportItemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 某个导入任务运行记录的失败文件列表。
  ///
  /// 弹层打开期间由承载组件按 3 秒节奏 invalidate，用于把「重试中」条目推进到
  /// 已解决/待处理。

  FailedImportItemsProvider call(int taskRunId) =>
      FailedImportItemsProvider._(argument: taskRunId, from: this);

  @override
  String toString() => r'failedImportItemsProvider';
}
