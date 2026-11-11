import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/language_providers.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_binding_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';

part 'plugin_bindings_provider.g.dart';

/// 当前互动数/评论来源绑定与可绑定插件。
@Riverpod(keepAlive: true)
Future<PluginBindingsDto> pluginBindings(Ref ref) {
  // 插件名与互动数字段文案由后端按请求语言解析，语言切换后需重新拉取。
  ref.watch(appLanguageControllerProvider);
  invalidateOnSessionChange(ref);
  return ref.watch(pluginsApiProvider).getBindings();
}
