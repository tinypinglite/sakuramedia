// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_rapid_upload_batch_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 秒传批次详情控制器（Riverpod family）：按 batchId 拉 `GET /media/rapid-uploads/{id}`
/// 得到含 items 的完整批次；`RapidUploadHistorySection` 展开批次卡时使用。
///
/// autoDispose：卡片折叠后卸载，重新展开时重新拉；页面级「展开批次 id 集合」由
/// hook `useState<Set<int>>` 管理，只要卡片仍展开，`ref.watch` 会让本 provider 保持
/// alive。

@ProviderFor(mediaRapidUploadBatchDetail)
final mediaRapidUploadBatchDetailProvider =
    MediaRapidUploadBatchDetailFamily._();

/// 秒传批次详情控制器（Riverpod family）：按 batchId 拉 `GET /media/rapid-uploads/{id}`
/// 得到含 items 的完整批次；`RapidUploadHistorySection` 展开批次卡时使用。
///
/// autoDispose：卡片折叠后卸载，重新展开时重新拉；页面级「展开批次 id 集合」由
/// hook `useState<Set<int>>` 管理，只要卡片仍展开，`ref.watch` 会让本 provider 保持
/// alive。

final class MediaRapidUploadBatchDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<MediaRapidUploadBatchDto>,
          MediaRapidUploadBatchDto,
          FutureOr<MediaRapidUploadBatchDto>
        >
    with
        $FutureModifier<MediaRapidUploadBatchDto>,
        $FutureProvider<MediaRapidUploadBatchDto> {
  /// 秒传批次详情控制器（Riverpod family）：按 batchId 拉 `GET /media/rapid-uploads/{id}`
  /// 得到含 items 的完整批次；`RapidUploadHistorySection` 展开批次卡时使用。
  ///
  /// autoDispose：卡片折叠后卸载，重新展开时重新拉；页面级「展开批次 id 集合」由
  /// hook `useState<Set<int>>` 管理，只要卡片仍展开，`ref.watch` 会让本 provider 保持
  /// alive。
  MediaRapidUploadBatchDetailProvider._({
    required MediaRapidUploadBatchDetailFamily super.from,
    required int super.argument,
  }) : super(
         retry: noMediaRapidUploadBatchDetailRetry,
         name: r'mediaRapidUploadBatchDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mediaRapidUploadBatchDetailHash();

  @override
  String toString() {
    return r'mediaRapidUploadBatchDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<MediaRapidUploadBatchDto> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MediaRapidUploadBatchDto> create(Ref ref) {
    final argument = this.argument as int;
    return mediaRapidUploadBatchDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MediaRapidUploadBatchDetailProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mediaRapidUploadBatchDetailHash() =>
    r'4a363d8c1b2457bc09fbd869918f01c8b65bdf65';

/// 秒传批次详情控制器（Riverpod family）：按 batchId 拉 `GET /media/rapid-uploads/{id}`
/// 得到含 items 的完整批次；`RapidUploadHistorySection` 展开批次卡时使用。
///
/// autoDispose：卡片折叠后卸载，重新展开时重新拉；页面级「展开批次 id 集合」由
/// hook `useState<Set<int>>` 管理，只要卡片仍展开，`ref.watch` 会让本 provider 保持
/// alive。

final class MediaRapidUploadBatchDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MediaRapidUploadBatchDto>, int> {
  MediaRapidUploadBatchDetailFamily._()
    : super(
        retry: noMediaRapidUploadBatchDetailRetry,
        name: r'mediaRapidUploadBatchDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 秒传批次详情控制器（Riverpod family）：按 batchId 拉 `GET /media/rapid-uploads/{id}`
  /// 得到含 items 的完整批次；`RapidUploadHistorySection` 展开批次卡时使用。
  ///
  /// autoDispose：卡片折叠后卸载，重新展开时重新拉；页面级「展开批次 id 集合」由
  /// hook `useState<Set<int>>` 管理，只要卡片仍展开，`ref.watch` 会让本 provider 保持
  /// alive。

  MediaRapidUploadBatchDetailProvider call(int batchId) =>
      MediaRapidUploadBatchDetailProvider._(argument: batchId, from: this);

  @override
  String toString() => r'mediaRapidUploadBatchDetailProvider';
}
