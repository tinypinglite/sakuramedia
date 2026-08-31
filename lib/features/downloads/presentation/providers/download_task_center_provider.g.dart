// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_task_center_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 下载任务中心：列表快照轮询 + 暂停/恢复/删除。

@ProviderFor(DownloadTaskCenter)
final downloadTaskCenterProvider = DownloadTaskCenterProvider._();

/// 下载任务中心：列表快照轮询 + 暂停/恢复/删除。
final class DownloadTaskCenterProvider
    extends
        $AsyncNotifierProvider<DownloadTaskCenter, DownloadTaskCenterState> {
  /// 下载任务中心：列表快照轮询 + 暂停/恢复/删除。
  DownloadTaskCenterProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'downloadTaskCenterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadTaskCenterHash();

  @$internal
  @override
  DownloadTaskCenter create() => DownloadTaskCenter();
}

String _$downloadTaskCenterHash() =>
    r'f59705ed4e19faf4a34e49ac10260c40c791d2a0';

/// 下载任务中心：列表快照轮询 + 暂停/恢复/删除。

abstract class _$DownloadTaskCenter
    extends $AsyncNotifier<DownloadTaskCenterState> {
  FutureOr<DownloadTaskCenterState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<DownloadTaskCenterState>,
              DownloadTaskCenterState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<DownloadTaskCenterState>,
                DownloadTaskCenterState
              >,
              AsyncValue<DownloadTaskCenterState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
