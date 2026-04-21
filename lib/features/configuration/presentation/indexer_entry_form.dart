import 'package:flutter/material.dart';
import 'package:sakuramedia/features/configuration/data/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_badge.dart';
import 'package:sakuramedia/widgets/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

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

String? validateIndexerDownloadClientField(int? value) {
  return value == null ? '请选择下载器' : null;
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
    required this.kind,
    required this.downloadClients,
    required this.selectedDownloadClientId,
    required this.onKindChanged,
    required this.onDownloadClientChanged,
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
  final String kind;
  final List<DownloadClientDto> downloadClients;
  final int? selectedDownloadClientId;
  final ValueChanged<String> onKindChanged;
  final ValueChanged<int?> onDownloadClientChanged;
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
          validator:
              (value) => validateIndexerNameField(
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
        AppSelectField<int>(
          key: const Key('indexer-entry-download-client-field'),
          value: selectedDownloadClientId,
          items: downloadClients
              .map(
                (client) => DropdownMenuItem<int>(
                  value: client.id,
                  child: Text(client.name),
                ),
              )
              .toList(growable: false),
          label: '绑定下载器',
          placeholder: downloadClients.isEmpty ? '请先在下载器页创建下载器' : '请选择下载器',
          onChanged:
              enabled && downloadClients.isNotEmpty
                  ? onDownloadClientChanged
                  : null,
          validator: validateIndexerDownloadClientField,
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
    final backgroundColor =
        kind == 'bt' ? colors.selectionSurface : colors.errorSurface;
    final foregroundColor =
        kind == 'bt'
            ? context.appTextPalette.accent
            : colors.errorAccentForeground;
    final icon =
        kind == 'bt' ? Icons.language_rounded : Icons.cloud_download_outlined;

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
    final backgroundColor =
        selected ? colors.selectionSurface : colors.surfaceMuted;
    final borderColor = selected ? colors.selectionBorder : colors.borderSubtle;
    final foregroundColor =
        selected
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
          style: resolveAppTextStyle(
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
