// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_bindings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 当前互动数/评论来源绑定与可绑定插件。

@ProviderFor(pluginBindings)
final pluginBindingsProvider = PluginBindingsProvider._();

/// 当前互动数/评论来源绑定与可绑定插件。

final class PluginBindingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<PluginBindingsDto>,
          PluginBindingsDto,
          FutureOr<PluginBindingsDto>
        >
    with
        $FutureModifier<PluginBindingsDto>,
        $FutureProvider<PluginBindingsDto> {
  /// 当前互动数/评论来源绑定与可绑定插件。
  PluginBindingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pluginBindingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pluginBindingsHash();

  @$internal
  @override
  $FutureProviderElement<PluginBindingsDto> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PluginBindingsDto> create(Ref ref) {
    return pluginBindings(ref);
  }
}

String _$pluginBindingsHash() => r'997cfe591d4da205422ed26b761642d1df37cce0';
