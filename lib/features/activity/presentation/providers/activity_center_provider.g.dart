// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_center_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ActivityCenter)
final activityCenterProvider = ActivityCenterProvider._();

final class ActivityCenterProvider
    extends $AsyncNotifierProvider<ActivityCenter, ActivityCenterState> {
  ActivityCenterProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'activityCenterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activityCenterHash();

  @$internal
  @override
  ActivityCenter create() => ActivityCenter();
}

String _$activityCenterHash() => r'9e067ef172ea2e9ac41beeb572fc72d08c8f4d2b';

abstract class _$ActivityCenter extends $AsyncNotifier<ActivityCenterState> {
  FutureOr<ActivityCenterState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ActivityCenterState>, ActivityCenterState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ActivityCenterState>, ActivityCenterState>,
              AsyncValue<ActivityCenterState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
