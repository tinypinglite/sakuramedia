import 'package:flutter/material.dart';
import 'package:sakuramedia/features/configuration/presentation/controllers/llm_settings_controller.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/llm_settings_copy.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/forms/app_password_field.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

/// LLM 设置表单核心字段：Base URL / API Key / 模型 / 请求超时 / 连接超时。
///
/// 桌面页与移动页共享的字段部分。启停按钮、概览、外壳由各端自行装配。
/// 通过 [keyPrefix] 让两端字段 Key 保持不同（例如 `configuration-llm` 和
/// `mobile-llm`），保测试锚点稳定。
class LlmSettingsFormFields extends StatelessWidget {
  const LlmSettingsFormFields({
    super.key,
    required this.controller,
    required this.keyPrefix,
  });

  final LlmSettingsController controller;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final autovalidateMode = controller.autovalidateMode;
    final fieldsEnabled = controller.fieldsEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          fieldKey: Key('$keyPrefix-base-url-field'),
          controller: controller.baseUrlController,
          label: 'Base URL',
          hintText: '请输入 http/https 地址',
          helperText: LlmSettingsCopy.baseUrlHelperText,
          enabled: fieldsEnabled,
          keyboardType: TextInputType.url,
          autovalidateMode: autovalidateMode,
          validator: llmBaseUrlError,
          onChanged: (_) => controller.handleDraftChanged(),
        ),
        SizedBox(height: spacing.md),
        AppPasswordField(
          fieldKey: Key('$keyPrefix-api-key-field'),
          visibilityButtonKey: Key('$keyPrefix-api-key-visibility-button'),
          controller: controller.apiKeyController,
          label: 'API Key',
          hintText: '可为空',
          enabled: fieldsEnabled,
          showLabel: '显示 API Key',
          hideLabel: '隐藏 API Key',
          onChanged: (_) => controller.handleDraftChanged(),
        ),
        SizedBox(height: spacing.md),
        AppTextField(
          fieldKey: Key('$keyPrefix-model-field'),
          controller: controller.modelController,
          label: '模型',
          hintText: LlmSettingsCopy.modelHintText,
          enabled: fieldsEnabled,
          autovalidateMode: autovalidateMode,
          validator: llmModelError,
          onChanged: (_) => controller.handleDraftChanged(),
        ),
        SizedBox(height: spacing.md),
        AppTextField(
          fieldKey: Key('$keyPrefix-timeout-field'),
          controller: controller.timeoutController,
          label: '请求超时（秒）',
          hintText: '请输入正数',
          enabled: fieldsEnabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autovalidateMode: autovalidateMode,
          validator: (value) => llmTimeoutError(value, label: '请求超时'),
          onChanged: (_) => controller.handleDraftChanged(),
        ),
        SizedBox(height: spacing.md),
        AppTextField(
          fieldKey: Key('$keyPrefix-connect-timeout-field'),
          controller: controller.connectTimeoutController,
          label: '连接超时（秒）',
          hintText: '请输入正数',
          enabled: fieldsEnabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autovalidateMode: autovalidateMode,
          validator: (value) => llmTimeoutError(value, label: '连接超时'),
          onChanged: (_) => controller.handleDraftChanged(),
        ),
      ],
    );
  }
}
