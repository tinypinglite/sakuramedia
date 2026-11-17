// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_metadata_match_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 单个失败文件的人工元数据搜索状态；结果按 (任务运行, 失败项) 隔离。

@ProviderFor(ImportMetadataMatch)
final importMetadataMatchProvider = ImportMetadataMatchFamily._();

/// 单个失败文件的人工元数据搜索状态；结果按 (任务运行, 失败项) 隔离。
final class ImportMetadataMatchProvider
    extends $NotifierProvider<ImportMetadataMatch, ImportMetadataMatchState> {
  /// 单个失败文件的人工元数据搜索状态；结果按 (任务运行, 失败项) 隔离。
  ImportMetadataMatchProvider._({
    required ImportMetadataMatchFamily super.from,
    required (int, String) super.argument,
  }) : super(
         retry: null,
         name: r'importMetadataMatchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$importMetadataMatchHash();

  @override
  String toString() {
    return r'importMetadataMatchProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  ImportMetadataMatch create() => ImportMetadataMatch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImportMetadataMatchState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImportMetadataMatchState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ImportMetadataMatchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$importMetadataMatchHash() =>
    r'deb56ac865d826a6f09448b93c764100e54b8af6';

/// 单个失败文件的人工元数据搜索状态；结果按 (任务运行, 失败项) 隔离。

final class ImportMetadataMatchFamily extends $Family
    with
        $ClassFamilyOverride<
          ImportMetadataMatch,
          ImportMetadataMatchState,
          ImportMetadataMatchState,
          ImportMetadataMatchState,
          (int, String)
        > {
  ImportMetadataMatchFamily._()
    : super(
        retry: null,
        name: r'importMetadataMatchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 单个失败文件的人工元数据搜索状态；结果按 (任务运行, 失败项) 隔离。

  ImportMetadataMatchProvider call(int taskRunId, String itemId) =>
      ImportMetadataMatchProvider._(argument: (taskRunId, itemId), from: this);

  @override
  String toString() => r'importMetadataMatchProvider';
}

/// 单个失败文件的人工元数据搜索状态；结果按 (任务运行, 失败项) 隔离。

abstract class _$ImportMetadataMatch
    extends $Notifier<ImportMetadataMatchState> {
  late final _$args = ref.$arg as (int, String);
  int get taskRunId => _$args.$1;
  String get itemId => _$args.$2;

  ImportMetadataMatchState build(int taskRunId, String itemId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<ImportMetadataMatchState, ImportMetadataMatchState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ImportMetadataMatchState, ImportMetadataMatchState>,
              ImportMetadataMatchState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
