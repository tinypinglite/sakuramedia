// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_tag_assignment_events_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MediaTagAssignmentEvents)
final mediaTagAssignmentEventsProvider = MediaTagAssignmentEventsProvider._();

final class MediaTagAssignmentEventsProvider
    extends
        $StreamNotifierProvider<
          MediaTagAssignmentEvents,
          MediaTagAssignmentChange
        > {
  MediaTagAssignmentEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaTagAssignmentEventsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaTagAssignmentEventsHash();

  @$internal
  @override
  MediaTagAssignmentEvents create() => MediaTagAssignmentEvents();
}

String _$mediaTagAssignmentEventsHash() =>
    r'46f8b0529dae64170ea5a2a1c14de9a8010d3efa';

abstract class _$MediaTagAssignmentEvents
    extends $StreamNotifier<MediaTagAssignmentChange> {
  Stream<MediaTagAssignmentChange> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<MediaTagAssignmentChange>,
              MediaTagAssignmentChange
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<MediaTagAssignmentChange>,
                MediaTagAssignmentChange
              >,
              AsyncValue<MediaTagAssignmentChange>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
