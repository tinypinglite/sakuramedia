import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/restart_messages.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_skeleton.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';

const _jsonEncoder = JsonEncoder.withIndent('  ');

/// 插件私有 JSON 配置的共享内容。
///
/// 这里集中负责读取、格式化、校验和保存，桌面与移动端只替换外层弹窗。
class PluginSettingsContent extends ConsumerStatefulWidget {
  const PluginSettingsContent({
    super.key,
    required this.plugin,
    this.mobile = false,
  });

  final PluginSummaryDto plugin;
  final bool mobile;

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

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
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
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = apiErrorMessage(error, fallback: '插件配置加载失败，请稍后重试。');
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
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      _lastValidatedSettings = null;
      return '配置不能为空';
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        _lastValidatedSettings = null;
        return '插件配置必须是一个 JSON 对象';
      }
      _lastValidatedSettings = decoded;
    } on FormatException {
      _lastValidatedSettings = null;
      return '不是合法的 JSON';
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
    final settings = _lastValidatedSettings;
    if (settings == null) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref
          .read(pluginsApiProvider)
          .updateSettings(widget.plugin.pluginId, settings: settings);
      if (!mounted) {
        return;
      }
      showToast(buildRestartRequiredMessage('插件配置已保存'));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      showToast(apiErrorMessage(error, fallback: '插件配置保存失败'));
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
        _buildDesktopBody(context),
      ],
    );
  }

  Widget _buildMobile(BuildContext context) {
    if (_loading || _errorMessage != null) {
      return _buildMobileStatusSheet(context);
    }
    return AppBottomFormSheet(
      formKey: _formKey,
      title: '插件配置',
      subtitle: '${widget.plugin.displayName} · ${widget.plugin.pluginId}',
      submitKey: const Key('plugin-settings-save-button'),
      isSubmitting: _saving,
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
            '插件配置',
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
          SizedBox(height: spacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: '取消',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppButton(
                  key: const Key('plugin-settings-save-button'),
                  label: '保存',
                  variant: AppButtonVariant.primary,
                  onPressed: null,
                ),
              ),
            ],
          ),
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
            '插件配置',
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

  Widget _buildDesktopBody(BuildContext context) {
    if (_loading) {
      return const AppSectionSkeleton(lineCount: 8);
    }
    if (_errorMessage != null) {
      return AppSectionError(
        title: '插件配置加载失败',
        message: _errorMessage!,
        onRetry: _load,
      );
    }
    return Form(
      key: _formKey,
      child: _buildFields(context, includeSaveButton: true),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    if (_loading) {
      return const AppMobileSkeletonList(
        itemCount: 2,
        padding: EdgeInsets.zero,
      );
    }
    if (_errorMessage != null) {
      return AppMobileSectionError(
        title: '插件配置加载失败',
        message: _errorMessage!,
        onRetry: _load,
        retryButtonKey: const Key('mobile-plugin-settings-retry-button'),
      );
    }
    return _buildFields(context, includeSaveButton: false);
  }

  Widget _buildFields(BuildContext context, {required bool includeSaveButton}) {
    final spacing = context.appSpacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          fieldKey: const Key('plugin-settings-json-field'),
          controller: _controller,
          label: '配置内容（JSON）',
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
            AppButton(
              key: const Key('plugin-settings-format-button'),
              label: '格式化',
              size: AppButtonSize.small,
              icon: const Icon(Icons.format_align_left_rounded),
              onPressed: _saving ? null : _format,
            ),
            if (includeSaveButton) ...[
              SizedBox(width: spacing.sm),
              AppButton(
                key: const Key('plugin-settings-save-button'),
                label: '保存',
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
