// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcements_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(announcementsApi)
final announcementsApiProvider = AnnouncementsApiProvider._();

final class AnnouncementsApiProvider
    extends
        $FunctionalProvider<
          AnnouncementsApi,
          AnnouncementsApi,
          AnnouncementsApi
        >
    with $Provider<AnnouncementsApi> {
  AnnouncementsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'announcementsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$announcementsApiHash();

  @$internal
  @override
  $ProviderElement<AnnouncementsApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AnnouncementsApi create(Ref ref) {
    return announcementsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnnouncementsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnnouncementsApi>(value),
    );
  }
}

String _$announcementsApiHash() => r'1594c24454d0da35c1ff16c2727480ee57897fbd';
