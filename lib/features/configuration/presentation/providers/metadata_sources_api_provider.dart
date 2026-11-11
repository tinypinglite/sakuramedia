import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/configuration/data/api/metadata_sources_api.dart';

final metadataSourcesApiProvider = Provider<MetadataSourcesApi>((ref) {
  return MetadataSourcesApi(apiClient: ref.watch(apiClientProvider));
});
