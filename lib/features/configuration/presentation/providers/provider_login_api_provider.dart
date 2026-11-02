import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/configuration/data/api/provider_login_api.dart';

part 'provider_login_api_provider.g.dart';

@Riverpod(keepAlive: true)
ProviderLoginApi providerLoginApi(Ref ref) {
  return ProviderLoginApi(apiClient: ref.watch(apiClientProvider));
}
