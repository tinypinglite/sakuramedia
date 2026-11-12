import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_bindings_provider.dart';

/// 互动数来源已绑定且当前插件可用。
final statsFeaturesEnabledProvider = Provider<bool>((ref) {
  final bindings = ref.watch(pluginBindingsProvider);
  if (bindings.hasError) return false;
  return bindings.value?.statsSourceAvailable ?? false;
});

/// 评论来源已显式绑定且当前插件可用。
final reviewFeaturesEnabledProvider = Provider<bool>((ref) {
  final bindings = ref.watch(pluginBindingsProvider);
  if (bindings.hasError) return false;
  return bindings.value?.reviewSourceAvailable ?? false;
});
