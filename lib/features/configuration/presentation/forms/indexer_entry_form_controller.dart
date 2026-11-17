import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';

/// 索引器编辑表单的本地状态。
///
/// 桌面弹窗与移动抽屉共用同一份初始化、选择顺序和 DTO 拼装逻辑；保存时机
/// 仍由两端各自的外壳决定。
class IndexerEntryFormController {
  IndexerEntryFormController({IndexerEntryDto? initialEntry})
    : _initialId = initialEntry?.id ?? 0,
      nameController = TextEditingController(text: initialEntry?.name ?? ''),
      urlController = TextEditingController(text: initialEntry?.url ?? ''),
      apiKeyController = TextEditingController(
        text: initialEntry?.apiKey ?? '',
      ),
      kind = initialEntry?.kind ?? 'pt',
      selectedDownloadClientIds = List<int>.of(
        initialEntry?.downloadClientIds ?? const <int>[],
      );

  final int _initialId;
  final TextEditingController nameController;
  final TextEditingController urlController;
  final TextEditingController apiKeyController;
  String kind;
  List<int> selectedDownloadClientIds;

  void dispose() {
    nameController.dispose();
    urlController.dispose();
    apiKeyController.dispose();
  }

  List<IndexerBoundClientDto> selectedDownloadClients(
    List<DownloadClientDto> downloadClients,
  ) {
    final clientsById = <int, DownloadClientDto>{
      for (final client in downloadClients) client.id: client,
    };
    return selectedDownloadClientIds
        .map((id) => clientsById[id])
        .whereType<DownloadClientDto>()
        .map(
          (client) => IndexerBoundClientDto(id: client.id, name: client.name),
        )
        .toList(growable: false);
  }

  IndexerEntryDto toDto(List<DownloadClientDto> downloadClients) {
    final apiKey = apiKeyController.text.trim();
    return IndexerEntryDto(
      id: _initialId,
      name: nameController.text.trim(),
      url: urlController.text.trim(),
      kind: kind,
      apiKey: apiKey.isEmpty ? null : apiKey,
      downloadClients: selectedDownloadClients(downloadClients),
    );
  }
}
