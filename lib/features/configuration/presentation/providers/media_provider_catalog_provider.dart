import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/language_providers.dart';
import 'package:sakuramedia/features/configuration/data/api/media_provider_catalog_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_provider_catalog_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';

part 'media_provider_catalog_provider.g.dart';

/// 当前账号可用的媒体 Provider Bundle 目录。
@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
class MediaProviderCatalog extends _$MediaProviderCatalog
    with AsyncNotifierDisposeGuardMixin<List<MediaProviderDto>> {
  MediaProviderCatalogApi get _api => ref.read(mediaProviderCatalogApiProvider);

  @override
  Future<List<MediaProviderDto>> build() async {
    // 目录里的 display_name / 配置字段 label 由后端按请求语言解析（读时文案），
    // 语言一变这份快照就过期，必须跟着重拉。
    ref.watch(appLanguageControllerProvider);
    invalidateOnSessionChange(ref);
    attachDisposeGuard();
    return _api.getProviders();
  }

  Future<void> reload() async {
    state = const AsyncLoading<List<MediaProviderDto>>();
    final next = await AsyncValue.guard(_api.getProviders);
    if (!isDisposed) {
      state = next;
    }
  }
}
