import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/plugins/presentation/widgets/plugin_settings_schema.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_api_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/features/plugins/presentation/widgets/plugin_settings_form.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_dismiss_controller.dart';

const _jsonEncoder = JsonEncoder.withIndent('  ');
const _javdbMetadataPluginId = 'sakuramedia_javdb_metadata';

/// 插件私有配置的共享内容。
///
/// 这里集中负责读取、格式化、校验和保存，桌面与移动端只替换外层弹窗。
class PluginSettingsContent extends ConsumerStatefulWidget {
  const PluginSettingsContent({
    super.key,
    required this.plugin,
    this.mobile = false,
    this.dismissController,
  });

  final PluginSummaryDto plugin;
  final bool mobile;
  final AppModalDismissController? dismissController;

  @override
  ConsumerState<PluginSettingsContent> createState() =>
      _PluginSettingsContentState();
}

class _PluginSettingsContentState extends ConsumerState<PluginSettingsContent> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;
  Map<String, dynamic>? _lastValidatedSettings;
  Map<String, dynamic>? _schema;
  Map<String, dynamic> _formSettings = {};
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    widget.dismissController?.setLocked(false);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    try {
      final result = await ref
          .read(pluginsApiProvider)
          .getSettings(widget.plugin.pluginId);
      if (!mounted) {
        return;
      }
      setState(() {
        _controller.text = _jsonEncoder.convert(result.settings);
        final schema = result.schema;
        _schema = schema == null ? null : pluginFormSchema(schema);
        if (_schema != null) {
          _formSettings = pluginFormValues(
            _schema!,
            result.defaults,
            result.settings,
          );
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      setState(() {
        _loading = false;
        _errorMessage = apiErrorMessage(
          error,
          fallback: l10n.pluginSettingsLoadFailedFallback,
          l10n: l10n,
        );
      });
    }
  }

  void _format() {
    try {
      final decoded = jsonDecode(_controller.text);
      _controller.text = _jsonEncoder.convert(decoded);
    } on FormatException {
      // 保持原文，校验会在提交时给出具体错误。
    }
    _formKey.currentState?.validate();
  }

  String? _validateJson(String? value) {
    final l10n = AppLocalizations.of(context);
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      _lastValidatedSettings = null;
      return l10n.pluginSettingsEmpty;
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        _lastValidatedSettings = null;
        return l10n.pluginSettingsMustBeObject;
      }
      _lastValidatedSettings = decoded;
    } on FormatException {
      _lastValidatedSettings = null;
      return l10n.pluginSettingsInvalidJson;
    }
    return null;
  }

  Future<void> _save() async {
    if (_loading ||
        _errorMessage != null ||
        !(_formKey.currentState?.validate() ?? false) ||
        _saving) {
      return;
    }
    final settings = _schema != null ? _formSettings : _lastValidatedSettings;
    if (settings == null) {
      return;
    }
    FocusScope.of(context).unfocus();
    widget.dismissController?.setLocked(true);
    setState(() => _saving = true);
    try {
      await ref
          .read(pluginsApiProvider)
          .updateSettings(widget.plugin.pluginId, settings: settings);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      widget.dismissController?.setLocked(false);
      setState(() {
        _saving = false;
        final details = error is ApiException ? error.error?.details : null;
        final fields = details?['fields'];
        if (fields is List) {
          _fieldErrors = {
            for (final field in fields.whereType<Map>())
              if (field['path'] is List && field['message'] is String)
                (field['path'] as List).join('.'): field['message'] as String,
          };
        }
      });
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.pluginSettingsSaveFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _formKey.currentState?.validate();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.mobile ? _buildMobile(context) : _buildDesktop(context);
  }

  Widget _buildDesktop(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        SizedBox(height: spacing.lg),
        Flexible(child: _buildDesktopBody(context)),
      ],
    );
  }

  Widget _buildMobile(BuildContext context) {
    if (_loading || _errorMessage != null) {
      return _buildMobileStatusSheet(context);
    }
    return AppBottomFormSheet(
      formKey: _formKey,
      title: AppLocalizations.of(context).pluginSettingsTitle,
      subtitle: '${widget.plugin.displayName} · ${widget.plugin.pluginId}',
      submitKey: const Key('plugin-settings-save-button'),
      isSubmitting: _saving,
      dismissController: widget.dismissController,
      onSubmit: () => unawaited(_save()),
      body: _buildMobileBody(context),
    );
  }

  Widget _buildMobileStatusSheet(BuildContext context) {
    final spacing = context.appSpacing;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppLocalizations.of(context).pluginSettingsTitle,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            '${widget.plugin.displayName} · ${widget.plugin.pluginId}',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.lg),
          _buildMobileBody(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final spacing = context.appSpacing;
    return Padding(
      padding: EdgeInsets.only(right: spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).pluginSettingsTitle,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            '${widget.plugin.displayName} · ${widget.plugin.pluginId}',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
        ],
      ),
    );
  }

  /// 加载态占位 Schema：让骨架按「有 Schema 的插件表单」形态渲染。
  static Map<String, dynamic> _placeholderSchema(AppLocalizations l10n) =>
      <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'endpoint': <String, dynamic>{
            'type': 'string',
            'title': l10n.pluginSettingsPlaceholderEndpoint,
          },
          'api_key': <String, dynamic>{
            'type': 'string',
            'title': l10n.commonApiKey,
          },
          'enabled': <String, dynamic>{
            'type': 'boolean',
            'title': l10n.pluginSettingsPlaceholderEnabled,
          },
        },
      };

  Widget _buildDesktopBody(BuildContext context) {
    if (_errorMessage != null) {
      return AppSectionError(
        title: AppLocalizations.of(context).pluginSettingsLoadFailed,
        message: _errorMessage!,
        onRetry: _load,
      );
    }
    // loading 用占位 Schema / 空表单渲染真实表单结构，由 [AppSkeletonizer] 灰化。
    final l10n = AppLocalizations.of(context);
    final schema = _schema ?? (_loading ? _placeholderSchema(l10n) : null);
    final values = _loading ? <String, dynamic>{} : _formSettings;
    return AppSkeletonizer(
      enabled: _loading,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: _buildFields(
                  context,
                  includeSaveButton: schema == null,
                  schema: schema,
                  values: values,
                ),
              ),
            ),
            if (schema != null) SizedBox(height: context.appSpacing.md),
            if (schema != null)
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  key: const Key('plugin-settings-save-button'),
                  label: l10n.commonSave,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  isLoading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    if (_errorMessage != null) {
      return AppMobileSectionError(
        title: AppLocalizations.of(context).pluginSettingsLoadFailed,
        message: _errorMessage!,
        onRetry: _load,
        retryButtonKey: const Key('mobile-plugin-settings-retry-button'),
      );
    }
    return AppSkeletonizer(
      enabled: _loading,
      child: _buildFields(
        context,
        includeSaveButton: false,
        schema:
            _schema ??
            (_loading
                ? _placeholderSchema(AppLocalizations.of(context))
                : null),
        values: _loading ? <String, dynamic>{} : _formSettings,
      ),
    );
  }

  Widget _buildFields(
    BuildContext context, {
    required bool includeSaveButton,
    Map<String, dynamic>? schema,
    Map<String, dynamic>? values,
  }) {
    final spacing = context.appSpacing;
    // 兼容旧调用：不传时仍按已加载的 Schema / 表单值渲染。
    final effectiveSchema = schema ?? _schema;
    final effectiveValues = values ?? _formSettings;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.plugin.pluginId == _javdbMetadataPluginId) ...[
          AppNoticeCard(
            key: const Key('plugin-settings-javdb-account-risk-notice'),
            leadingIcon: Icons.warning_amber_rounded,
            description: AppLocalizations.of(
              context,
            ).pluginSettingsJavdbAccountRisk,
          ),
          SizedBox(height: spacing.md),
        ],
        if (effectiveSchema != null)
          PluginSettingsForm(
            schema: effectiveSchema,
            values: effectiveValues,
            enabled: !_saving,
            fieldErrors: _fieldErrors,
            onEdited: () {
              if (_fieldErrors.isNotEmpty) {
                setState(() {
                  _fieldErrors = {};
                });
              }
            },
          )
        else
          AppTextField(
            fieldKey: const Key('plugin-settings-json-field'),
            controller: _controller,
            label: AppLocalizations.of(context).pluginSettingsJsonLabel,
            hintText: '{ "key": "value" }',
            minLines: 14,
            maxLines: 14,
            enabled: !_saving,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
            ).copyWith(fontFamilyFallback: kAppMonospaceFontFallback),
            validator: _validateJson,
          ),
        SizedBox(height: spacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (effectiveSchema == null)
              AppButton(
                key: const Key('plugin-settings-format-button'),
                label: AppLocalizations.of(context).pluginSettingsFormat,
                size: AppButtonSize.small,
                icon: const Icon(Icons.format_align_left_rounded),
                onPressed: _saving ? null : _format,
              ),
            if (includeSaveButton) ...[
              SizedBox(width: spacing.sm),
              AppButton(
                key: const Key('plugin-settings-save-button'),
                label: AppLocalizations.of(context).commonSave,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                isLoading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
