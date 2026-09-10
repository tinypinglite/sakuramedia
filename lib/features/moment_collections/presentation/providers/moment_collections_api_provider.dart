import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/moment_collections/data/api/moment_collections_api.dart';

part 'moment_collections_api_provider.g.dart';

@Riverpod(keepAlive: true)
MomentCollectionsApi momentCollectionsApi(Ref ref) {
  return MomentCollectionsApi(apiClient: ref.watch(apiClientProvider));
}
