// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcement_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AnnouncementFeed)
final announcementFeedProvider = AnnouncementFeedProvider._();

final class AnnouncementFeedProvider
    extends $NotifierProvider<AnnouncementFeed, AnnouncementFeedState> {
  AnnouncementFeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'announcementFeedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$announcementFeedHash();

  @$internal
  @override
  AnnouncementFeed create() => AnnouncementFeed();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnnouncementFeedState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnnouncementFeedState>(value),
    );
  }
}

String _$announcementFeedHash() => r'a9dcf1ef3bdc68e7e2abad2cad331add91a36684';

abstract class _$AnnouncementFeed extends $Notifier<AnnouncementFeedState> {
  AnnouncementFeedState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AnnouncementFeedState, AnnouncementFeedState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AnnouncementFeedState, AnnouncementFeedState>,
              AnnouncementFeedState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
