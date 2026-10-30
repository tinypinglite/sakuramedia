// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'series_import_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 每次系列导入弹窗独占一个 autoDispose 流状态机。

@ProviderFor(SeriesImport)
final seriesImportProvider = SeriesImportFamily._();

/// 每次系列导入弹窗独占一个 autoDispose 流状态机。
final class SeriesImportProvider
    extends $NotifierProvider<SeriesImport, SeriesImportState> {
  /// 每次系列导入弹窗独占一个 autoDispose 流状态机。
  SeriesImportProvider._({
    required SeriesImportFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'seriesImportProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$seriesImportHash();

  @override
  String toString() {
    return r'seriesImportProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SeriesImport create() => SeriesImport();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SeriesImportState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SeriesImportState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SeriesImportProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$seriesImportHash() => r'002ff3d4c50f047e3c02d332853bb2def4a027af';

/// 每次系列导入弹窗独占一个 autoDispose 流状态机。

final class SeriesImportFamily extends $Family
    with
        $ClassFamilyOverride<
          SeriesImport,
          SeriesImportState,
          SeriesImportState,
          SeriesImportState,
          int
        > {
  SeriesImportFamily._()
    : super(
        retry: null,
        name: r'seriesImportProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 每次系列导入弹窗独占一个 autoDispose 流状态机。

  SeriesImportProvider call(int seriesId) =>
      SeriesImportProvider._(argument: seriesId, from: this);

  @override
  String toString() => r'seriesImportProvider';
}

/// 每次系列导入弹窗独占一个 autoDispose 流状态机。

abstract class _$SeriesImport extends $Notifier<SeriesImportState> {
  late final _$args = ref.$arg as int;
  int get seriesId => _$args;

  SeriesImportState build(int seriesId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SeriesImportState, SeriesImportState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SeriesImportState, SeriesImportState>,
              SeriesImportState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
