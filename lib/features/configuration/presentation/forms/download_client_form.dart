import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_config_form.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';
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

String? validateDownloadClientName(
  String? value, {
  required AppLocalizations l10n,
}) {
  if (value == null || value.trim().isEmpty) {
    return l10n.downloaderNameRequired;
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          fieldKey: const Key('download-client-name-field'),
          controller: nameController,
          focusNode: nameFocusNode,
          enabled: enabled,
          label: l10n.downloaderNameLabel,
          hintText: l10n.downloaderNameHint,
          validator: (value) => validateDownloadClientName(value, l10n: l10n),
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
          label: l10n.downloaderTargetLibrary,
          placeholder: libraries.isEmpty
              ? l10n.downloaderNoDownloadableLibraries
              : l10n.downloaderSelectTargetLibrary,
          onChanged: enabled && libraries.isNotEmpty ? onLibraryChanged : null,
          validator: (value) =>
              value == null ? l10n.downloaderSelectTargetLibrary : null,
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
  const DownloadClientDiagnosticResultView({super.key, required this.report});

  final DownloadClientDiagnosticReportDto report;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
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
                  l10n.downloaderTestResultTitle,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.medium,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
              AppStatusChip(
                label: _statusLabel(l10n, report.status),
                palette: AppStatusChipPalette.forSemantic(
                  _semantic(report.status),
                ),
                dense: true,
              ),
            ],
          ),
          SizedBox(height: spacing.xs),
          Text(
            _summary(l10n, report.status),
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

  static String _statusLabel(AppLocalizations l10n, String status) =>
      switch (status) {
        'ok' => l10n.downloaderTestStatusOk,
        'warning' => l10n.downloaderTestStatusWarning,
        _ => l10n.downloaderTestStatusFailed,
      };

  static AppStatusSemantic _semantic(String status) => switch (status) {
    'ok' => AppStatusSemantic.success,
    'warning' => AppStatusSemantic.warning,
    _ => AppStatusSemantic.error,
  };

  static String _summary(AppLocalizations l10n, String status) =>
      switch (status) {
        'ok' => l10n.downloaderTestSummaryOk,
        'warning' => l10n.downloaderTestSummaryWarning,
        _ => l10n.downloaderTestSummaryFailed,
      };
}

class _DiagnosticCheckRow extends StatelessWidget {
  const _DiagnosticCheckRow({required this.check});

  final DownloadClientDiagnosticCheckDto check;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppStatusChip(
          label: _statusLabel(l10n, check.status),
          palette: AppStatusChipPalette.forSemantic(_semantic(check.status)),
          dense: true,
        ),
        SizedBox(width: spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _checkLabel(l10n, check.key),
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

  static String _statusLabel(AppLocalizations l10n, String status) =>
      switch (status) {
        'ok' => l10n.downloaderCheckStatusOk,
        'warning' => l10n.downloaderCheckStatusWarning,
        'skipped' => l10n.downloaderCheckStatusSkipped,
        _ => l10n.downloaderCheckStatusFailed,
      };

  static AppStatusSemantic _semantic(String status) => switch (status) {
    'ok' => AppStatusSemantic.success,
    'warning' => AppStatusSemantic.warning,
    'skipped' => AppStatusSemantic.neutral,
    _ => AppStatusSemantic.error,
  };

  static String _checkLabel(AppLocalizations l10n, String key) => switch (key) {
    'qbittorrent_connection' => l10n.downloaderCheckQbittorrent,
    'directory_mapping' => l10n.downloaderCheckDirectoryMapping,
    'hardlink' => l10n.downloaderCheckHardlink,
    'cleanup' => l10n.downloaderCheckCleanup,
    'provider' => l10n.downloaderCheckProvider,
    _ => key,
  };
}
