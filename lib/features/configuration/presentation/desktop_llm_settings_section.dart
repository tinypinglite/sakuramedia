import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/movie_desc_translation_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/movie_desc_translation_settings_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_badge.dart';
import 'package:sakuramedia/widgets/app_shell/app_content_card.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

enum _LlmConfigTestState { idle, success, failure }

class DesktopLlmSettingsSection extends StatefulWidget {
  const DesktopLlmSettingsSection({super.key});

  @override
  State<DesktopLlmSettingsSection> createState() =>
      _DesktopLlmSettingsSectionState();
}

class _DesktopLlmSettingsSectionState extends State<DesktopLlmSettingsSection> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _timeoutController;
  late final TextEditingController _connectTimeoutController;

  bool _enabled = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;
  bool _obscureApiKey = true;
  bool _showValidation = false;
  String? _errorMessage;
  _LlmConfigTestState _testState = _LlmConfigTestState.idle;

  MovieDescTranslationSettingsApi get _api =>
      context.read<MovieDescTranslationSettingsApi>();

  bool get _hasCompleteConfig {
    return _baseUrlError(_baseUrlController.text) == null &&
        _modelError(_modelController.text) == null &&
        _timeoutError(_timeoutController.text, label: '请求超时') == null &&
        _timeoutError(_connectTimeoutController.text, label: '连接超时') == null;
  }

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController();
    _apiKeyController = TextEditingController();
    _modelController = TextEditingController();
    _timeoutController = TextEditingController();
    _connectTimeoutController = TextEditingController();
    unawaited(_loadSettings());
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _timeoutController.dispose();
    _connectTimeoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return AppContentCard(
      key: const Key('configuration-llm-card'),
      title: 'LLM 配置',
      padding: EdgeInsets.all(spacing.lg),
      titleStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s18,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
      headerBottomSpacing: spacing.md,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const _DesktopLlmSkeleton();
    }

    if (_errorMessage != null) {
      return _DesktopLlmErrorState(
        message: _errorMessage!,
        onRetry: _loadSettings,
      );
    }

    final spacing = context.appSpacing;
    final autovalidateMode =
        _showValidation ? AutovalidateMode.always : AutovalidateMode.disabled;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '当前页面管理 LLM 服务接入参数，现阶段由影片简介翻译任务使用。',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ),
              SizedBox(width: spacing.md),
              AppBadge(
                label: _enabled ? '已启用' : '已停用',
                tone: _enabled ? AppBadgeTone.success : AppBadgeTone.warning,
                size: AppBadgeSize.compact,
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Text(
            '入口名称保持通用 LLM 配置，当前后端实际接入的是影片简介翻译服务。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: spacing.lg),
          Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            children: [
              _DesktopLlmOverviewStat(
                label: '启用状态',
                value: _enabled ? '已启用' : '已停用',
              ),
              _DesktopLlmOverviewStat(
                label: '配置完整度',
                value: _hasCompleteConfig ? '可保存' : '待补齐',
              ),
              _DesktopLlmOverviewStat(
                label: '最近测试',
                value: switch (_testState) {
                  _LlmConfigTestState.idle => '未测试',
                  _LlmConfigTestState.success => '测试通过',
                  _LlmConfigTestState.failure => '测试失败',
                },
              ),
            ],
          ),
          SizedBox(height: spacing.lg),
          Text(
            '启用状态',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.sm),
          Row(
            children: [
              SizedBox(
                width: 180,
                child: AppButton(
                  key: const Key('configuration-llm-enabled-button'),
                  label: '已启用',
                  variant: AppButtonVariant.secondary,
                  isSelected: _enabled,
                  onPressed:
                      _isSaving || _isTesting
                          ? null
                          : () => _updateEnabled(true),
                ),
              ),
              SizedBox(width: spacing.sm),
              SizedBox(
                width: 180,
                child: AppButton(
                  key: const Key('configuration-llm-disabled-button'),
                  label: '已停用',
                  variant: AppButtonVariant.secondary,
                  isSelected: !_enabled,
                  onPressed:
                      _isSaving || _isTesting
                          ? null
                          : () => _updateEnabled(false),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.lg),
          AppTextField(
            fieldKey: const Key('configuration-llm-base-url-field'),
            controller: _baseUrlController,
            label: 'Base URL',
            hintText: '请输入 http/https 地址',
            helperText: '例如：http://127.0.0.1:8000',
            enabled: !_isSaving && !_isTesting,
            keyboardType: TextInputType.url,
            autovalidateMode: autovalidateMode,
            validator: _baseUrlError,
            onChanged: (_) => _handleDraftChanged(),
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('configuration-llm-api-key-field'),
            controller: _apiKeyController,
            label: 'API Key',
            hintText: '可为空',
            enabled: !_isSaving && !_isTesting,
            obscureText: _obscureApiKey,
            suffix: AppIconButton(
              key: const Key('configuration-llm-api-key-visibility-button'),
              tooltip: _obscureApiKey ? '显示 API Key' : '隐藏 API Key',
              semanticLabel: _obscureApiKey ? '显示 API Key' : '隐藏 API Key',
              size: AppIconButtonSize.compact,
              icon: Icon(
                _obscureApiKey
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed:
                  _isSaving || _isTesting
                      ? null
                      : () => setState(() {
                        _obscureApiKey = !_obscureApiKey;
                      }),
            ),
            onChanged: (_) => _handleDraftChanged(),
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('configuration-llm-model-field'),
            controller: _modelController,
            label: '模型',
            hintText: '例如：gpt-4o-mini',
            enabled: !_isSaving && !_isTesting,
            autovalidateMode: autovalidateMode,
            validator: _modelError,
            onChanged: (_) => _handleDraftChanged(),
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('configuration-llm-timeout-field'),
            controller: _timeoutController,
            label: '请求超时（秒）',
            hintText: '请输入正数',
            enabled: !_isSaving && !_isTesting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autovalidateMode: autovalidateMode,
            validator: (value) => _timeoutError(value, label: '请求超时'),
            onChanged: (_) => _handleDraftChanged(),
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('configuration-llm-connect-timeout-field'),
            controller: _connectTimeoutController,
            label: '连接超时（秒）',
            hintText: '请输入正数',
            enabled: !_isSaving && !_isTesting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autovalidateMode: autovalidateMode,
            validator: (value) => _timeoutError(value, label: '连接超时'),
            onChanged: (_) => _handleDraftChanged(),
          ),
          SizedBox(height: spacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                width: 220,
                child: AppButton(
                  key: const Key('configuration-llm-test-button'),
                  label: '测试配置',
                  isLoading: _isTesting,
                  onPressed: _isSaving ? null : _handleTest,
                ),
              ),
              SizedBox(width: spacing.md),
              SizedBox(
                width: 220,
                child: AppButton(
                  key: const Key('configuration-llm-save-button'),
                  label: '保存配置',
                  variant: AppButtonVariant.primary,
                  isLoading: _isSaving,
                  onPressed: _isTesting ? null : _handleSave,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final settings = await _api.getSettings();
      if (!mounted) {
        return;
      }
      setState(() {
        _applySettings(settings);
        _testState = _LlmConfigTestState.idle;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = apiErrorMessage(error, fallback: 'LLM 配置加载失败，请稍后重试。');
      });
    }
  }

  Future<void> _handleSave() async {
    final payload = _buildUpdatePayload();
    if (payload == null || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final saved = await _api.updateSettings(payload);
      if (!mounted) {
        return;
      }
      setState(() {
        _applySettings(saved);
        _testState = _LlmConfigTestState.idle;
        _isSaving = false;
      });
      showToast('LLM 配置已保存');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      showToast(apiErrorMessage(error, fallback: '保存 LLM 配置失败'));
    }
  }

  Future<void> _handleTest() async {
    final payload = _buildTestPayload();
    if (payload == null || _isTesting) {
      return;
    }

    setState(() {
      _isTesting = true;
    });

    try {
      final ok = await _api.testSettings(payload);
      if (!mounted) {
        return;
      }
      setState(() {
        _isTesting = false;
        _testState =
            ok ? _LlmConfigTestState.success : _LlmConfigTestState.failure;
      });
      showToast(ok ? '测试通过' : '测试失败');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isTesting = false;
        _testState = _LlmConfigTestState.failure;
      });
      showToast(apiErrorMessage(error, fallback: '测试 LLM 配置失败'));
    }
  }

  void _applySettings(MovieDescTranslationSettingsDto settings) {
    _enabled = settings.enabled;
    _baseUrlController.text = settings.baseUrl;
    _apiKeyController.text = settings.apiKey;
    _modelController.text = settings.model;
    _timeoutController.text = _formatNumber(settings.timeoutSeconds);
    _connectTimeoutController.text = _formatNumber(
      settings.connectTimeoutSeconds,
    );
    _showValidation = false;
    _errorMessage = null;
  }

  void _updateEnabled(bool enabled) {
    if (_enabled == enabled) {
      return;
    }
    setState(() {
      _enabled = enabled;
      _testState = _LlmConfigTestState.idle;
    });
  }

  void _handleDraftChanged() {
    if (_testState == _LlmConfigTestState.idle) {
      return;
    }
    setState(() {
      _testState = _LlmConfigTestState.idle;
    });
  }

  UpdateMovieDescTranslationSettingsPayload? _buildUpdatePayload() {
    if (!_validateForm()) {
      return null;
    }
    return UpdateMovieDescTranslationSettingsPayload(
      enabled: _enabled,
      baseUrl: _baseUrlController.text.trim(),
      apiKey: _apiKeyController.text,
      model: _modelController.text.trim(),
      timeoutSeconds: double.parse(_timeoutController.text.trim()),
      connectTimeoutSeconds: double.parse(
        _connectTimeoutController.text.trim(),
      ),
    );
  }

  TestMovieDescTranslationSettingsPayload? _buildTestPayload() {
    if (!_validateForm()) {
      return null;
    }
    return TestMovieDescTranslationSettingsPayload(
      enabled: _enabled,
      baseUrl: _baseUrlController.text.trim(),
      apiKey: _apiKeyController.text,
      model: _modelController.text.trim(),
      timeoutSeconds: double.parse(_timeoutController.text.trim()),
      connectTimeoutSeconds: double.parse(
        _connectTimeoutController.text.trim(),
      ),
    );
  }

  bool _validateForm() {
    setState(() {
      _showValidation = true;
    });
    return _formKey.currentState?.validate() ?? false;
  }

  String? _baseUrlError(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty || !_isValidHttpUrl(trimmed)) {
      return '请输入合法的 http/https 地址';
    }
    return null;
  }

  String? _modelError(String? value) {
    if ((value?.trim() ?? '').isEmpty) {
      return '请输入模型名称';
    }
    return null;
  }

  String? _timeoutError(String? value, {required String label}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '请输入$label';
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed <= 0) {
      return '$label必须是正数';
    }
    return null;
  }

  String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
}

class _DesktopLlmOverviewStat extends StatelessWidget {
  const _DesktopLlmOverviewStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: EdgeInsets.all(context.appSpacing.md),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: context.appSpacing.xs),
          Text(
            label,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopLlmErrorState extends StatelessWidget {
  const _DesktopLlmErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('configuration-llm-error-state'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppEmptyState(message: message),
        SizedBox(height: context.appSpacing.lg),
        AppButton(
          key: const Key('configuration-llm-retry-button'),
          onPressed: () => onRetry(),
          icon: const Icon(Icons.refresh_rounded),
          label: '重试',
        ),
      ],
    );
  }
}

class _DesktopLlmSkeleton extends StatelessWidget {
  const _DesktopLlmSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(6, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: context.appSpacing.md),
          child: Container(
            width: double.infinity,
            height: index == 1 ? 84 : 20,
            decoration: BoxDecoration(
              color: context.appColors.surfaceMuted,
              borderRadius: context.appRadius.smBorder,
            ),
          ),
        );
      }),
    );
  }
}

bool _isValidHttpUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.hasScheme &&
      uri.hasAuthority &&
      (uri.scheme == 'http' || uri.scheme == 'https');
}
