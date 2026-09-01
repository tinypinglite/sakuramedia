import 'package:flutter/material.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/forms/app_password_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';

String? validateIndexerNameField(
  String? value, {
  List<IndexerEntryDto> existingEntries = const <IndexerEntryDto>[],
  int? editingEntryId,
}) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return '请输入索引器名称';
  }
  final duplicates = existingEntries.where((item) {
    if (editingEntryId != null && item.id == editingEntryId) {
      return false;
    }
    return item.name.trim().toLowerCase() == trimmed.toLowerCase();
  });
  if (duplicates.isNotEmpty) {
    return '索引器名称重复';
  }
  return null;
}

String? validateIndexerUrlField(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return '请输入索引器 URL';
  }
  if (!isValidIndexerHttpUrl(trimmed)) {
    return '请输入合法的 http/https 地址';
  }
  return null;
}

String? validateIndexerDownloadClientsField(List<int>? value) {
  return value == null || value.isEmpty ? '请至少选择一个下载器' : null;
}

bool isValidIndexerHttpUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      (uri.host.isNotEmpty || uri.hasAuthority);
}

bool isSupportedIndexerKind(String value) {
  return value == 'pt' || value == 'bt';
}

Set<String> findDuplicateIndexerNames(List<IndexerEntryDto> items) {
  final seen = <String>{};
  final duplicates = <String>{};
  for (final item in items) {
    final normalized = item.name.trim().toLowerCase();
    if (normalized.isEmpty) {
      continue;
    }
    if (!seen.add(normalized)) {
      duplicates.add(item.name.trim());
    }
  }
  return duplicates;
}

class IndexerEntryFormFields extends StatelessWidget {
  const IndexerEntryFormFields({
    super.key,
    required this.nameController,
    required this.urlController,
    required this.apiKeyController,
    required this.kind,
    required this.downloadClients,
    required this.selectedDownloadClientIds,
    required this.onKindChanged,
    required this.onDownloadClientsChanged,
    this.existingEntries = const <IndexerEntryDto>[],
    this.editingEntryId,
    this.enabled = true,
    this.autovalidateMode,
    this.nameFocusNode,
    this.urlFocusNode,
    this.onSubmitted,
  });

  final TextEditingController nameController;
  final TextEditingController urlController;
  final TextEditingController apiKeyController;
  final String kind;
  final List<DownloadClientDto> downloadClients;
  final List<int> selectedDownloadClientIds;
  final ValueChanged<String> onKindChanged;
  final ValueChanged<List<int>> onDownloadClientsChanged;
  final List<IndexerEntryDto> existingEntries;
  final int? editingEntryId;
  final bool enabled;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? nameFocusNode;
  final FocusNode? urlFocusNode;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IndexerFormFieldLabel(label: '名称 (NAME)'),
        SizedBox(height: spacing.sm),
        AppTextField(
          fieldKey: const Key('indexer-entry-name-field'),
          controller: nameController,
          focusNode: nameFocusNode,
          hintText: '例如: 馒头',
          enabled: enabled,
          autovalidateMode: autovalidateMode,
          textInputAction: TextInputAction.next,
          validator: (value) => validateIndexerNameField(
            value,
            existingEntries: existingEntries,
            editingEntryId: editingEntryId,
          ),
        ),
        SizedBox(height: spacing.lg),
        const IndexerFormFieldLabel(label: '资源地址 (URL)'),
        SizedBox(height: spacing.sm),
        AppTextField(
          fieldKey: const Key('indexer-entry-url-field'),
          controller: urlController,
          focusNode: urlFocusNode,
          hintText: '填写完整的 torznab 地址',
          enabled: enabled,
          autovalidateMode: autovalidateMode,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => onSubmitted?.call(),
          validator: validateIndexerUrlField,
        ),
        SizedBox(height: spacing.lg),
        const IndexerFormFieldLabel(label: 'API Key (可选)'),
        SizedBox(height: spacing.sm),
        AppPasswordField(
          fieldKey: const Key('indexer-entry-api-key-field'),
          controller: apiKeyController,
          hintText: '留空则请求不携带 apikey',
          enabled: enabled,
          autovalidateMode: autovalidateMode,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => onSubmitted?.call(),
          showLabel: '显示 API Key',
          hideLabel: '隐藏 API Key',
        ),
        SizedBox(height: spacing.lg),
        const IndexerFormFieldLabel(label: '类别 (KIND)'),
        SizedBox(height: spacing.sm),
        Row(
          key: const Key('indexer-entry-kind-field'),
          children: [
            Expanded(
              child: IndexerKindOptionButton(
                label: 'PT (私有)',
                selected: kind == 'pt',
                enabled: enabled,
                onTap: () => onKindChanged('pt'),
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: IndexerKindOptionButton(
                label: 'BT (公网)',
                selected: kind == 'bt',
                enabled: enabled,
                onTap: () => onKindChanged('bt'),
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.lg),
        KeyedSubtree(
          key: const Key('indexer-entry-download-client-field'),
          child: FormField<List<int>>(
            key: ValueKey<String>(
              '$kind:${selectedDownloadClientIds.join(',')}',
            ),
            initialValue: selectedDownloadClientIds,
            validator: validateIndexerDownloadClientsField,
            builder: (field) {
              final clientsById = <int, DownloadClientDto>{
                for (final client in downloadClients) client.id: client,
              };
              final selectedClients = selectedDownloadClientIds
                  .map((id) => clientsById[id])
                  .whereType<DownloadClientDto>()
                  .toList(growable: false);
              final selectedClientIds = selectedDownloadClientIds.toSet();
              final unboundClients = downloadClients
                  .where((client) => !selectedClientIds.contains(client.id))
                  .toList(growable: false);

              void updateSelection(List<int> next) {
                field.didChange(next);
                onDownloadClientsChanged(next);
              }

              void add(DownloadClientDto client) {
                if (!enabled) return;
                final next = List<int>.of(selectedDownloadClientIds);
                next.add(client.id);
                updateSelection(next);
              }

              void remove(DownloadClientDto client) {
                if (!enabled) return;
                final next = List<int>.of(selectedDownloadClientIds)
                  ..remove(client.id);
                updateSelection(next);
              }

              void move(int index, int offset) {
                if (!enabled) return;
                final nextIndex = index + offset;
                if (nextIndex < 0 ||
                    nextIndex >= selectedDownloadClientIds.length) {
                  return;
                }
                final next = List<int>.of(selectedDownloadClientIds);
                final clientId = next.removeAt(index);
                next.insert(nextIndex, clientId);
                updateSelection(next);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const IndexerFormFieldLabel(label: '下载器优先级'),
                  SizedBox(height: spacing.sm),
                  Text(
                    '首位下载器将作为自动下载和资源投递的默认目标。',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.muted,
                    ),
                  ),
                  SizedBox(height: spacing.sm),
                  if (downloadClients.isEmpty)
                    AppSettingsGroup(
                      children: [AppSettingCell(title: '请先在下载器页创建下载器')],
                    )
                  else ...[
                    if (selectedClients.isEmpty)
                      AppSettingsGroup(
                        header: '已绑定下载器',
                        children: const [
                          AppSettingCell(
                            icon: Icons.download_outlined,
                            title: '尚未绑定下载器',
                            subtitle: '请从下方添加至少一个下载器',
                          ),
                        ],
                      )
                    else
                      AppSettingsGroup(
                        header: '已绑定下载器',
                        children: [
                          for (
                            var index = 0;
                            index < selectedClients.length;
                            index++
                          )
                            AppSettingCell(
                              key: Key(
                                'indexer-download-client-${selectedClients[index].id}',
                              ),
                              icon: index == 0
                                  ? Icons.download_done_rounded
                                  : Icons.download_rounded,
                              iconColor: index == 0
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              title: selectedClients[index].name,
                              subtitle: index == 0
                                  ? '默认下载器'
                                  : '优先级 ${index + 1}',
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppIconButton(
                                    key: Key(
                                      'indexer-download-client-move-up-${selectedClients[index].id}',
                                    ),
                                    icon: const Icon(
                                      Icons.arrow_upward_rounded,
                                    ),
                                    onPressed: !enabled || index == 0
                                        ? null
                                        : () => move(index, -1),
                                    tooltip: '上移',
                                    semanticLabel:
                                        '上移 ${selectedClients[index].name}',
                                  ),
                                  AppIconButton(
                                    key: Key(
                                      'indexer-download-client-move-down-${selectedClients[index].id}',
                                    ),
                                    icon: const Icon(
                                      Icons.arrow_downward_rounded,
                                    ),
                                    onPressed:
                                        !enabled ||
                                            index == selectedClients.length - 1
                                        ? null
                                        : () => move(index, 1),
                                    tooltip: '下移',
                                    semanticLabel:
                                        '下移 ${selectedClients[index].name}',
                                  ),
                                  AppTextButton(
                                    key: Key(
                                      'indexer-download-client-remove-${selectedClients[index].id}',
                                    ),
                                    onPressed: enabled
                                        ? () => remove(selectedClients[index])
                                        : null,
                                    label: '移除',
                                    size: AppTextButtonSize.xSmall,
                                    backgroundStyle:
                                        AppTextButtonBackgroundStyle.muted,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    if (unboundClients.isNotEmpty) ...[
                      SizedBox(height: spacing.md),
                      AppSettingsGroup(
                        header: '添加下载器',
                        children: [
                          for (final client in unboundClients)
                            AppSettingCell(
                              key: Key('indexer-download-client-${client.id}'),
                              icon: Icons.download_outlined,
                              title: client.name,
                              subtitle: '未绑定',
                              trailing: AppTextButton(
                                key: Key(
                                  'indexer-download-client-add-${client.id}',
                                ),
                                onPressed: enabled ? () => add(client) : null,
                                label: '添加',
                                size: AppTextButtonSize.xSmall,
                                emphasis: AppTextButtonEmphasis.accent,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                  if (field.hasError) ...[
                    SizedBox(height: spacing.xs),
                    Text(
                      field.errorText!,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        tone: AppTextTone.error,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class IndexerSourceAvatar extends StatelessWidget {
  const IndexerSourceAvatar({super.key, required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final layoutTokens = context.appLayoutTokens;
    final backgroundColor = kind == 'bt'
        ? colors.selectionSurface
        : colors.errorSurface;
    final foregroundColor = kind == 'bt'
        ? context.appTextPalette.accent
        : colors.errorAccentForeground;
    final icon = kind == 'bt'
        ? Icons.language_rounded
        : Icons.cloud_download_outlined;

    return Container(
      width: layoutTokens.panelIconContainerSize,
      height: layoutTokens.panelIconContainerSize,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: context.appRadius.mdBorder,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: context.appComponentTokens.iconSizeLg,
        color: foregroundColor,
      ),
    );
  }
}

class IndexerKindBadge extends StatelessWidget {
  const IndexerKindBadge({super.key, required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: kind == 'bt' ? 'BT' : 'PT',
      tone: kind == 'bt' ? AppBadgeTone.primary : AppBadgeTone.error,
      size: AppBadgeSize.compact,
    );
  }
}

class IndexerKindOptionButton extends StatelessWidget {
  const IndexerKindOptionButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final layoutTokens = context.appLayoutTokens;
    final backgroundColor = selected
        ? colors.selectionSurface
        : colors.surfaceMuted;
    final borderColor = selected ? colors.selectionBorder : colors.borderSubtle;
    final foregroundColor = selected
        ? context.appTextPalette.accent
        : context.appTextPalette.secondary;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: context.appRadius.mdBorder,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: layoutTokens.segmentedControlHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? backgroundColor : colors.surfaceMuted,
          borderRadius: context.appRadius.mdBorder,
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style:
              resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.tertiary,
              ).copyWith(
                color: enabled ? foregroundColor : context.appTextPalette.muted,
              ),
        ),
      ),
    );
  }
}

class IndexerFormFieldLabel extends StatelessWidget {
  const IndexerFormFieldLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        weight: AppTextWeight.regular,
        tone: AppTextTone.secondary,
      ),
    );
  }
}
