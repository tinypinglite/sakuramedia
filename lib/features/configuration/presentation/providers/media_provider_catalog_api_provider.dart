import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/configuration/data/api/media_provider_catalog_api.dart';

part 'media_provider_catalog_api_provider.g.dart';

@Riverpod(keepAlive: true)
MediaProviderCatalogApi mediaProviderCatalogApi(Ref ref) {
  return MediaProviderCatalogApi(apiClient: ref.watch(apiClientProvider));
}
