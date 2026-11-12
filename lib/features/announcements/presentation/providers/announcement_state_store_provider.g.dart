// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcement_state_store_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 公告已读/已确认状态。生产在应用组合根注入 SharedPreferences 实现。

@ProviderFor(announcementStateStore)
final announcementStateStoreProvider = AnnouncementStateStoreProvider._();

/// 公告已读/已确认状态。生产在应用组合根注入 SharedPreferences 实现。

final class AnnouncementStateStoreProvider
    extends
        $FunctionalProvider<
          AnnouncementStateStore,
          AnnouncementStateStore,
          AnnouncementStateStore
        >
    with $Provider<AnnouncementStateStore> {
  /// 公告已读/已确认状态。生产在应用组合根注入 SharedPreferences 实现。
  AnnouncementStateStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'announcementStateStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$announcementStateStoreHash();

  @$internal
  @override
  $ProviderElement<AnnouncementStateStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AnnouncementStateStore create(Ref ref) {
    return announcementStateStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnnouncementStateStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnnouncementStateStore>(value),
    );
  }
}

String _$announcementStateStoreHash() =>
    r'b00c35a6bc194b99eb4a77f7e064c2ed97f49c89';
