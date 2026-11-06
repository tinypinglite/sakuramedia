import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';

part 'download_clients_provider.g.dart';

/// 跨桌面 configuration tab 与移动设置页共享的下载器列表。
@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
class DownloadClients extends _$DownloadClients
    with AsyncNotifierDisposeGuardMixin<List<DownloadClientDto>> {
  @override
  Future<List<DownloadClientDto>> build() async {
    invalidateOnSignOut(ref);
    attachDisposeGuard();
    return ref.read(downloadClientsApiProvider).getClients();
  }

  Future<void> reload() async {
    state = const AsyncLoading<List<DownloadClientDto>>();
    final next = await AsyncValue.guard(
      () => ref.read(downloadClientsApiProvider).getClients(),
    );
    if (!isDisposed) state = next;
  }

  /// 下拉刷新保留已呈现的列表；失败交给调用方展示轻提示。
  Future<String?> refresh() async {
    final current = state.value;
    if (current == null) {
      await reload();
      return state.hasError
          ? ref.apiErrorMessage(
              state.error!,
              fallback: ref
                  .read(appLocalizationsProvider)
                  .errorDownloadClientLoadFailed,
            )
          : null;
    }
    try {
      final next = await ref.read(downloadClientsApiProvider).getClients();
      if (!isDisposed) state = AsyncData(next);
      return null;
    } catch (error) {
      return ref.apiErrorMessage(
        error,
        fallback: ref
            .read(appLocalizationsProvider)
            .errorDownloadClientLoadFailed,
      );
    }
  }

  Future<DownloadClientDto> create(CreateDownloadClientPayload payload) async {
    final created = await ref
        .read(downloadClientsApiProvider)
        .createClient(payload);
    upsert(created);
    return created;
  }

  Future<DownloadClientDto> updateClient({
    required int clientId,
    required UpdateDownloadClientPayload payload,
  }) async {
    final updated = await ref
        .read(downloadClientsApiProvider)
        .updateClient(clientId: clientId, payload: payload);
    upsert(updated);
    return updated;
  }

  Future<void> delete(int clientId) async {
    await ref.read(downloadClientsApiProvider).deleteClient(clientId);
    if (isDisposed) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.where((client) => client.id != clientId).toList(growable: false),
    );
  }

  void upsert(DownloadClientDto client) {
    if (isDisposed) return;
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((item) => item.id == client.id);
    final next = List<DownloadClientDto>.from(current);
    if (index < 0) {
      next.insert(0, client);
    } else {
      next[index] = client;
    }
    state = AsyncData(next);
  }
}
