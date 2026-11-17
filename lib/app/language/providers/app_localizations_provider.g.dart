// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_localizations_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 当前语言对应的 [AppLocalizations]。
///
/// widget 仍优先用 `AppLocalizations.of(context)`；provider/data 层没有
/// BuildContext，通过这个 provider 取同一份当前语言文案。

@ProviderFor(appLocalizations)
final appLocalizationsProvider = AppLocalizationsProvider._();

/// 当前语言对应的 [AppLocalizations]。
///
/// widget 仍优先用 `AppLocalizations.of(context)`；provider/data 层没有
/// BuildContext，通过这个 provider 取同一份当前语言文案。

final class AppLocalizationsProvider
    extends
        $FunctionalProvider<
          AppLocalizations,
          AppLocalizations,
          AppLocalizations
        >
    with $Provider<AppLocalizations> {
  /// 当前语言对应的 [AppLocalizations]。
  ///
  /// widget 仍优先用 `AppLocalizations.of(context)`；provider/data 层没有
  /// BuildContext，通过这个 provider 取同一份当前语言文案。
  AppLocalizationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLocalizationsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLocalizationsHash();

  @$internal
  @override
  $ProviderElement<AppLocalizations> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppLocalizations create(Ref ref) {
    return appLocalizations(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppLocalizations value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppLocalizations>(value),
    );
  }
}

String _$appLocalizationsHash() => r'e7680f2ac11b12be4c2af7785df795ef2f3f15c3';
