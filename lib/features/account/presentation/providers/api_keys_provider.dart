import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/account/data/account_dto.dart';
import 'package:sakuramedia/features/account/presentation/providers/account_api_provider.dart';

part 'api_keys_provider.g.dart';

/// API 密钥列表：生成/删除后就地更新状态，不整表重拉。
@riverpod
class ApiKeys extends _$ApiKeys {
  @override
  Future<List<ApiKeyDto>> build() {
    return ref.read(accountApiProvider).listApiKeys();
  }

  /// 生成密钥并返回明文（仅此一次）；失败抛出给调用方展示。
  Future<ApiKeyCreatedDto> create({String name = ''}) async {
    final created = await ref.read(accountApiProvider).createApiKey(name: name);
    final current = state.value ?? const <ApiKeyDto>[];
    state = AsyncData(<ApiKeyDto>[created, ...current]);
    return created;
  }

  /// 删除（吊销）密钥；失败抛出给调用方展示。
  Future<void> delete(int keyId) async {
    await ref.read(accountApiProvider).deleteApiKey(keyId);
    final current = state.value ?? const <ApiKeyDto>[];
    state = AsyncData(<ApiKeyDto>[
      for (final item in current)
        if (item.id != keyId) item,
    ]);
  }
}
