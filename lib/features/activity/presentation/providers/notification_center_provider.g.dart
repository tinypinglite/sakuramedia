// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_center_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 全局常驻通知中心，登录后通过通知列表快照轮询。

@ProviderFor(NotificationCenter)
final notificationCenterProvider = NotificationCenterProvider._();

/// 全局常驻通知中心，登录后通过通知列表快照轮询。
final class NotificationCenterProvider
    extends $NotifierProvider<NotificationCenter, NotificationCenterState> {
  /// 全局常驻通知中心，登录后通过通知列表快照轮询。
  NotificationCenterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationCenterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationCenterHash();

  @$internal
  @override
  NotificationCenter create() => NotificationCenter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationCenterState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationCenterState>(value),
    );
  }
}

String _$notificationCenterHash() =>
    r'4bd4d1cda218e3cd2de104d2f40b9b053b5d2066';

/// 全局常驻通知中心，登录后通过通知列表快照轮询。

abstract class _$NotificationCenter extends $Notifier<NotificationCenterState> {
  NotificationCenterState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<NotificationCenterState, NotificationCenterState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<NotificationCenterState, NotificationCenterState>,
              NotificationCenterState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
