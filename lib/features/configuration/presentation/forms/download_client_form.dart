import 'package:flutter/material.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_config_form.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

/// The local snapshot used to turn the editor into an API payload.
class DownloadClientFormValue {
  const DownloadClientFormValue({
    required this.name,
    required this.libraryId,
    required this.providerConfig,
    this.providerConfigAvailable = true,
  });

  factory DownloadClientFormValue.fromControllers({
    required TextEditingController nameController,
    required ProviderConfigFormController providerConfigController,
    required bool isEditing,
    required int? libraryId,
    bool providerConfigAvailable = true,
  }) {
    return DownloadClientFormValue(
      name: nameController.text.trim(),
      libraryId: libraryId,
      providerConfig: isEditing
          ? providerConfigController.toUpdateProviderConfig()
          : providerConfigController.toCreateProviderConfig(),
      providerConfigAvailable: providerConfigAvailable,
    );
  }

  final String name;
  final int? libraryId;
  final Map<String, dynamic> providerConfig;
  final bool providerConfigAvailable;

  CreateDownloadClientPayload toCreatePayload() {
    final selectedLibraryId = libraryId;
    if (selectedLibraryId == null) {
      throw StateError('download client requires a media library');
    }
    return CreateDownloadClientPayload(
      name: name,
      libraryId: selectedLibraryId,
      providerConfig: providerConfig,
    );
  }

  UpdateDownloadClientPayload toUpdatePayload() {
    return UpdateDownloadClientPayload(
      name: name,
      libraryId: libraryId,
      providerConfig: providerConfigAvailable ? providerConfig : null,
    );
  }
}

String? validateDownloadClientName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '请输入下载器名称';
  }
  return null;
}

/// Provider-neutral download client editor.
///
/// [libraries] is expected to contain only media libraries whose provider
/// advertises download support. The selected library determines the provider
/// configuration fields rendered below; this widget never exposes a provider
/// kind selector or provider-specific fields.
class DownloadClientFormFields extends StatelessWidget {
  const DownloadClientFormFields({
    super.key,
    required this.nameController,
    required this.libraries,
    required this.selectedLibraryId,
    required this.onLibraryChanged,
    required this.providerConfigController,
    required this.isEditing,
    this.enabled = true,
    this.autovalidateMode,
    this.nameFocusNode,
    this.libraryFocusNode,
    this.fieldSpacing,
    this.onSubmitted,
  });

  final TextEditingController nameController;
  final List<MediaLibraryDto> libraries;
  final int? selectedLibraryId;
  final ValueChanged<int?> onLibraryChanged;
  final ProviderConfigFormController providerConfigController;
  final bool isEditing;
  final bool enabled;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? nameFocusNode;
  final FocusNode? libraryFocusNode;
  final double? fieldSpacing;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final spacing = fieldSpacing ?? context.appSpacing.lg;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          fieldKey: const Key('download-client-name-field'),
          controller: nameController,
          focusNode: nameFocusNode,
          enabled: enabled,
          label: '名称',
          hintText: '给下载器起个名字',
          validator: validateDownloadClientName,
          autovalidateMode: autovalidateMode,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => libraryFocusNode?.requestFocus(),
        ),
        SizedBox(height: spacing),
        AppSelectField<int>(
          key: const Key('download-client-media-library-field'),
          value: selectedLibraryId,
          items: libraries
              .map(
                (library) => DropdownMenuItem<int>(
                  value: library.id,
                  child: Text(library.name),
                ),
              )
              .toList(growable: false),
          label: '目标媒体库',
          placeholder: libraries.isEmpty ? '暂无支持下载的媒体库' : '请选择目标媒体库',
          onChanged: enabled && libraries.isNotEmpty ? onLibraryChanged : null,
          validator: (value) => value == null ? '请选择目标媒体库' : null,
        ),
        if (providerConfigController.fields.isNotEmpty) ...[
          SizedBox(height: spacing),
          ProviderConfigFormFields(
            controller: providerConfigController,
            enabled: enabled,
            autovalidateMode: autovalidateMode,
            isEditing: isEditing,
            fieldSpacing: spacing,
          ),
        ],
      ],
    );
  }
}

class DownloadClientDiagnosticResultView extends StatelessWidget {
  const DownloadClientDiagnosticResultView({
    super.key,
    required this.report,
  });

  final DownloadClientDiagnosticReportDto report;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final tone = _tone(report.status);
    final colors = context.appColors;
    final surface = switch (report.status) {
      'ok' => colors.successSurface,
      'warning' => colors.warningSurface,
      _ => colors.errorSurface,
    };
    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '配置测试结果',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.medium,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
              AppBadge(
                label: _statusLabel(report.status),
                tone: tone,
                size: AppBadgeSize.compact,
              ),
            ],
          ),
          SizedBox(height: spacing.xs),
          Text(
            _summary(report.status),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.md),
          for (var index = 0; index < report.checks.length; index++) ...[
            if (index > 0) SizedBox(height: spacing.sm),
            _DiagnosticCheckRow(check: report.checks[index]),
          ],
        ],
      ),
    );
  }

  static String _statusLabel(String status) => switch (status) {
    'ok' => '通过',
    'warning' => '有警告',
    _ => '未通过',
  };

  static AppBadgeTone _tone(String status) => switch (status) {
    'ok' => AppBadgeTone.success,
    'warning' => AppBadgeTone.warning,
    _ => AppBadgeTone.error,
  };

  static String _summary(String status) => switch (status) {
    'ok' => '所有检查已通过，可以保存并开始使用。',
    'warning' => '检测完成，但存在警告。配置仍可保存，导入时可能回退为复制。',
    _ => '检测未通过。配置仍可保存，但下载任务或导入可能失败。',
  };
}

class _DiagnosticCheckRow extends StatelessWidget {
  const _DiagnosticCheckRow({required this.check});

  final DownloadClientDiagnosticCheckDto check;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppBadge(
          label: _statusLabel(check.status),
          tone: _tone(check.status),
          size: AppBadgeSize.compact,
        ),
        SizedBox(width: spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _checkLabel(check.key),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.medium,
                  tone: AppTextTone.primary,
                ),
              ),
              SizedBox(height: spacing.xs),
              Text(
                check.message,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _statusLabel(String status) => switch (status) {
    'ok' => '通过',
    'warning' => '警告',
    'skipped' => '未执行',
    _ => '失败',
  };

  static AppBadgeTone _tone(String status) => switch (status) {
    'ok' => AppBadgeTone.success,
    'warning' => AppBadgeTone.warning,
    'skipped' => AppBadgeTone.neutral,
    _ => AppBadgeTone.error,
  };

  static String _checkLabel(String key) => switch (key) {
    'qbittorrent_connection' => 'qBittorrent 连通性',
    'directory_mapping' => '下载目录映射',
    'hardlink' => '硬链接',
    'cleanup' => '临时文件清理',
    'provider' => '下载器测试',
    _ => key,
  };
}
