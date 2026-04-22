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
import 'package:sakuramedia/widgets/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/app_shell/app_badge.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

class MobileLlmSettingsPage extends StatefulWidget {
  const MobileLlmSettingsPage({super.key});

  @override
  State<MobileLlmSettingsPage> createState() => _MobileLlmSettingsPageState();
}

enum _LlmConfigTestState { idle, success, failure }

class _MobileLlmSettingsPageState extends State<MobileLlmSettingsPage> {
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

  MovieDescTranslationSettingsApi get _api =>
      context.read<MovieDescTranslationSettingsApi>();

  bool get _hasCompleteConfig {
    return _baseUrlError(_baseUrlController.text) == null &&
        _modelError(_modelController.text) == null &&
        _timeoutError(_timeoutController.text, label: '请求超时') == null &&
        _timeoutError(_connectTimeoutController.text, label: '连接超时') == null;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return ColoredBox(
      key: const Key('mobile-settings-llm'),
      color: colors.surfaceCard,
      child: Column(
        children: [
          Expanded(
            child: AppAdaptiveRefreshScrollView(
              onRefresh: _refreshSettings,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.md,
                    spacing.md,
                    spacing.md,
                    spacing.lg,
                  ),
                  sliver: SliverToBoxAdapter(child: _buildBody(context)),
                ),
              ],
            ),
          ),
          if (_errorMessage == null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(
                spacing.md,
                spacing.md,
                spacing.md,
                spacing.md,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceCard,
                border: Border(top: BorderSide(color: colors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      key: const Key('mobile-llm-test-button'),
                      label: '测试配置',
                      isLoading: _isTesting,
                      onPressed: _isSaving ? null : _handleTest,
                    ),
                  ),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: AppButton(
                      key: const Key('mobile-llm-save-button'),
                      label: '保存配置',
                      variant: AppButtonVariant.primary,
                      isLoading: _isSaving,
                      onPressed: _isTesting ? null : _handleSave,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const _MobileLlmLoadingSection();
    }

    if (_errorMessage != null) {
      return _MobileLlmErrorSection(
        message: _errorMessage!,
        onRetry: _loadSettings,
      );
    }

    final spacing = context.appSpacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MobileLlmOverviewCard(
          enabled: _enabled,
          hasCompleteConfig: _hasCompleteConfig,
          testState: _testState,
        ),
        SizedBox(height: spacing.md),
        _buildFormCard(context),
      ],
    );
  }

  Widget _buildFormCard(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final autovalidateMode =
        _showValidation ? AutovalidateMode.always : AutovalidateMode.disabled;

    return Container(
      key: const Key('mobile-llm-form-card'),
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'LLM 接入配置',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s14,
                      weight: AppTextWeight.semibold,
                      tone: AppTextTone.primary,
                    ),
                  ),
                ),
                AppBadge(
                  label: _enabled ? '已启用' : '已停用',
                  tone: _enabled ? AppBadgeTone.success : AppBadgeTone.warning,
                  size: AppBadgeSize.compact,
                ),
              ],
            ),
            SizedBox(height: spacing.xs),
            Text(
              '当前页面管理 LLM 服务接入参数，现阶段由影片简介翻译任务使用。',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
            SizedBox(height: spacing.md),
            Text(
              '启用状态',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
            SizedBox(height: spacing.xs),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    key: const Key('mobile-llm-enabled-button'),
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
                Expanded(
                  child: AppButton(
                    key: const Key('mobile-llm-disabled-button'),
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
            SizedBox(height: spacing.md),
            AppTextField(
              fieldKey: const Key('mobile-llm-base-url-field'),
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
              fieldKey: const Key('mobile-llm-api-key-field'),
              controller: _apiKeyController,
              label: 'API Key',
              hintText: '可为空',
              enabled: !_isSaving && !_isTesting,
              obscureText: _obscureApiKey,
              suffix: AppIconButton(
                key: const Key('mobile-llm-api-key-visibility-button'),
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
              fieldKey: const Key('mobile-llm-model-field'),
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
              fieldKey: const Key('mobile-llm-timeout-field'),
              controller: _timeoutController,
              label: '请求超时（秒）',
              hintText: '请输入正数',
              enabled: !_isSaving && !_isTesting,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autovalidateMode: autovalidateMode,
              validator: (value) => _timeoutError(value, label: '请求超时'),
              onChanged: (_) => _handleDraftChanged(),
            ),
            SizedBox(height: spacing.md),
            AppTextField(
              fieldKey: const Key('mobile-llm-connect-timeout-field'),
              controller: _connectTimeoutController,
              label: '连接超时（秒）',
              hintText: '请输入正数',
              enabled: !_isSaving && !_isTesting,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autovalidateMode: autovalidateMode,
              validator: (value) => _timeoutError(value, label: '连接超时'),
              onChanged: (_) => _handleDraftChanged(),
            ),
          ],
        ),
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

  Future<void> _refreshSettings() async {
    try {
      final settings = await _api.getSettings();
      if (!mounted) {
        return;
      }
      setState(() {
        _applySettings(settings);
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: 'LLM 配置加载失败，请稍后重试。'));
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

class _MobileLlmOverviewCard extends StatelessWidget {
  const _MobileLlmOverviewCard({
    required this.enabled,
    required this.hasCompleteConfig,
    required this.testState,
  });

  final bool enabled;
  final bool hasCompleteConfig;
  final _LlmConfigTestState testState;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return Container(
      key: const Key('mobile-llm-overview-card'),
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.noticeSurface,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '先确认服务地址和模型，再决定是否启用，并可直接用当前草稿发起测试。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            '入口名称保持通用 LLM 配置，当前后端实际接入的是影片简介翻译服务。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.md),
          Row(
            children: [
              Expanded(
                child: _MobileLlmOverviewStat(
                  label: '启用状态',
                  value: enabled ? '已启用' : '已停用',
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: _MobileLlmOverviewStat(
                  label: '配置完整度',
                  value: hasCompleteConfig ? '可保存' : '待补齐',
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: _MobileLlmOverviewStat(
                  label: '最近测试',
                  value: switch (testState) {
                    _LlmConfigTestState.idle => '未测试',
                    _LlmConfigTestState.success => '测试通过',
                    _LlmConfigTestState.failure => '测试失败',
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileLlmOverviewStat extends StatelessWidget {
  const _MobileLlmOverviewStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.appSpacing.sm),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
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
              size: AppTextSize.s10,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileLlmLoadingSection extends StatelessWidget {
  const _MobileLlmLoadingSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MobileLlmSkeletonCard(height: context.appSpacing.xxl * 3.4),
        SizedBox(height: context.appSpacing.md),
        _MobileLlmSkeletonCard(height: context.appSpacing.xxl * 5.8),
      ],
    );
  }
}

class _MobileLlmSkeletonCard extends StatelessWidget {
  const _MobileLlmSkeletonCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.lgBorder,
      ),
    );
  }
}

class _MobileLlmErrorSection extends StatelessWidget {
  const _MobileLlmErrorSection({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mobile-llm-error-state'),
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.md,
        vertical: context.appSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Column(
        children: [
          AppEmptyState(message: message),
          AppButton(
            key: const Key('mobile-llm-retry-button'),
            label: '重试',
            onPressed: () {
              unawaited(onRetry());
            },
          ),
        ],
      ),
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
