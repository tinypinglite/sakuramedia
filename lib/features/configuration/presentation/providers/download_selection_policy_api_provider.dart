import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/configuration/data/api/download_selection_policy_api.dart';

part 'download_selection_policy_api_provider.g.dart';

@Riverpod(keepAlive: true)
DownloadSelectionPolicyApi downloadSelectionPolicyApi(Ref ref) {
  return DownloadSelectionPolicyApi(apiClient: ref.watch(apiClientProvider));
}
