// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_profile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 账号资料（用户名/创建时间/上次登录）+ 修改用户名。
///
/// keepAlive：账号资料是全局共享数据（configuration 桌面段 + mobile 改用户名页
/// 都消费）；首次加载后跨页保留，切换 tab 不重拉。登出/重新登录走
/// [invalidateOnSessionChange] 失效——组合根的 ObjectKey 绑的是 SessionStore
/// 实例，同一次运行内登出换账号**不会**重建 ProviderScope，keepAlive 状态必须
/// 自行处理会话边沿。
///
/// 迁移前对应：`AccountProfileController`（configuration section + mobile
/// change_username page 两处各自 late final 构造）。四态复合（account /
/// isLoading / isSaving / errorMessage）AsyncValue 表达不了，故用同步 Notifier +
/// 显式 [AccountProfileState]（对齐批 2 `OverviewSystemInfo` 样板）。

@ProviderFor(AccountProfile)
final accountProfileProvider = AccountProfileProvider._();

/// 账号资料（用户名/创建时间/上次登录）+ 修改用户名。
///
/// keepAlive：账号资料是全局共享数据（configuration 桌面段 + mobile 改用户名页
/// 都消费）；首次加载后跨页保留，切换 tab 不重拉。登出/重新登录走
/// [invalidateOnSessionChange] 失效——组合根的 ObjectKey 绑的是 SessionStore
/// 实例，同一次运行内登出换账号**不会**重建 ProviderScope，keepAlive 状态必须
/// 自行处理会话边沿。
///
/// 迁移前对应：`AccountProfileController`（configuration section + mobile
/// change_username page 两处各自 late final 构造）。四态复合（account /
/// isLoading / isSaving / errorMessage）AsyncValue 表达不了，故用同步 Notifier +
/// 显式 [AccountProfileState]（对齐批 2 `OverviewSystemInfo` 样板）。
final class AccountProfileProvider
    extends $NotifierProvider<AccountProfile, AccountProfileState> {
  /// 账号资料（用户名/创建时间/上次登录）+ 修改用户名。
  ///
  /// keepAlive：账号资料是全局共享数据（configuration 桌面段 + mobile 改用户名页
  /// 都消费）；首次加载后跨页保留，切换 tab 不重拉。登出/重新登录走
  /// [invalidateOnSessionChange] 失效——组合根的 ObjectKey 绑的是 SessionStore
  /// 实例，同一次运行内登出换账号**不会**重建 ProviderScope，keepAlive 状态必须
  /// 自行处理会话边沿。
  ///
  /// 迁移前对应：`AccountProfileController`（configuration section + mobile
  /// change_username page 两处各自 late final 构造）。四态复合（account /
  /// isLoading / isSaving / errorMessage）AsyncValue 表达不了，故用同步 Notifier +
  /// 显式 [AccountProfileState]（对齐批 2 `OverviewSystemInfo` 样板）。
  AccountProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountProfileProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountProfileHash();

  @$internal
  @override
  AccountProfile create() => AccountProfile();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountProfileState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountProfileState>(value),
    );
  }
}

String _$accountProfileHash() => r'c6fbd0e9203ec115dc465b01da4234052cdd614b';

/// 账号资料（用户名/创建时间/上次登录）+ 修改用户名。
///
/// keepAlive：账号资料是全局共享数据（configuration 桌面段 + mobile 改用户名页
/// 都消费）；首次加载后跨页保留，切换 tab 不重拉。登出/重新登录走
/// [invalidateOnSessionChange] 失效——组合根的 ObjectKey 绑的是 SessionStore
/// 实例，同一次运行内登出换账号**不会**重建 ProviderScope，keepAlive 状态必须
/// 自行处理会话边沿。
///
/// 迁移前对应：`AccountProfileController`（configuration section + mobile
/// change_username page 两处各自 late final 构造）。四态复合（account /
/// isLoading / isSaving / errorMessage）AsyncValue 表达不了，故用同步 Notifier +
/// 显式 [AccountProfileState]（对齐批 2 `OverviewSystemInfo` 样板）。

abstract class _$AccountProfile extends $Notifier<AccountProfileState> {
  AccountProfileState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AccountProfileState, AccountProfileState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AccountProfileState, AccountProfileState>,
              AccountProfileState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
