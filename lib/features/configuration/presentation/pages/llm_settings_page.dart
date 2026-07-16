import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/llm_settings_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/llm_settings_state.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/llm_settings_copy.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/base/forms/app_password_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';

/// Desktop 配置区和 Mobile 设置路由共同使用的唯一 LLM 设置页面。
///
/// [active] 只服务 Desktop IndexedStack 的懒加载；它不是平台或布局分支。
class LlmSettingsPage extends StatefulWidget {
  const LlmSettingsPage({super.key, this.active = true});

  final bool active;

  @override
  State<LlmSettingsPage> createState() => _LlmSettingsPageState();
}

class _LlmSettingsPageState extends State<LlmSettingsPage> {
  late bool _hasStarted = widget.active;

  @override
  void didUpdateWidget(covariant LlmSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_hasStarted) {
      _hasStarted = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasStarted) {
      return const SizedBox.shrink();
    }
    return const _StartedLlmSettingsPage();
  }
}

class _StartedLlmSettingsPage extends ConsumerWidget {
  const _StartedLlmSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSettings = ref.watch(llmSettingsProvider);
    final settings = asyncSettings.value;
    final spacing = context.appSpacing;

    return ColoredBox(
      key: const Key('llm-settings-page'),
      color: context.appColors.surfaceCard,
      child: Column(
        children: [
          Expanded(
            child: AppAdaptiveRefreshScrollView(
              onRefresh: () async {
                final message =
                    await ref.read(llmSettingsProvider.notifier).refresh();
                if (context.mounted && message != null) {
                  showToast(message);
                }
              },
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.md,
                    spacing.md,
                    spacing.md,
                    spacing.xl,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: asyncSettings.when(
                      data: (value) => _LlmSettingsContent(settings: value),
                      error:
                          (error, stackTrace) => _LlmSettingsError(
                            message: apiErrorMessage(
                              error,
                              fallback: 'LLM 配置加载失败',
                            ),
                            onRetry:
                                ref.read(llmSettingsProvider.notifier).reload,
                          ),
                      loading: () => const _LlmSettingsSkeleton(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (settings != null)
            _LlmSettingsFooter(
              settings: settings,
              onTest: () async {
                final message =
                    await ref
                        .read(llmSettingsProvider.notifier)
                        .runConnectionTest();
                if (context.mounted && message != null) {
                  showToast(message);
                }
              },
              onSave: () async {
                final message =
                    await ref.read(llmSettingsProvider.notifier).save();
                if (context.mounted && message != null) {
                  showToast(message);
                }
              },
            ),
        ],
      ),
    );
  }
}

class _LlmSettingsContent extends StatelessWidget {
  const _LlmSettingsContent({required this.settings});

  final LlmSettingsState settings;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppNoticeCard(
          key: const Key('llm-overview-card'),
          title: '先确认服务地址和模型，再决定是否启用，并可直接用当前草稿发起测试。',
          description: LlmSettingsCopy.sharedEndpointDescription,
          stats: [
            AppNoticeStat(
              label: '启用状态',
              value: settings.draft.enabled ? '已启用' : '已停用',
            ),
            AppNoticeStat(
              label: '配置完整度',
              value: settings.hasCompleteConfig ? '可保存' : '待补齐',
            ),
            AppNoticeStat(label: '最近测试', value: settings.testStateLabel),
          ],
        ),
        SizedBox(height: spacing.md),
        AppContentCard(
          key: const Key('llm-form-card'),
          title: 'LLM 接入配置',
          padding: EdgeInsets.all(spacing.lg),
          headerBottomSpacing: spacing.md,
          headerTrailing: AppBadge(
            label: settings.draft.enabled ? '已启用' : '已停用',
            tone:
                settings.draft.enabled
                    ? AppBadgeTone.success
                    : AppBadgeTone.warning,
            size: AppBadgeSize.compact,
          ),
          child: _LlmSettingsFormHost(settings: settings),
        ),
      ],
    );
  }
}

class _LlmSettingsFormHost extends HookConsumerWidget {
  const _LlmSettingsFormHost({required this.settings});

  final LlmSettingsState settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = settings.draft;
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final baseUrlController = useTextEditingController(text: draft.baseUrl);
    final apiKeyController = useTextEditingController(text: draft.apiKey);
    final modelController = useTextEditingController(text: draft.model);
    final timeoutController = useTextEditingController(
      text: draft.timeoutSeconds,
    );
    final connectTimeoutController = useTextEditingController(
      text: draft.connectTimeoutSeconds,
    );
    final baseUrlFocusNode = useFocusNode();
    final apiKeyFocusNode = useFocusNode();
    final modelFocusNode = useFocusNode();
    final timeoutFocusNode = useFocusNode();
    final connectTimeoutFocusNode = useFocusNode();

    useEffect(() {
      _syncController(baseUrlController, draft.baseUrl);
      _syncController(apiKeyController, draft.apiKey);
      _syncController(modelController, draft.model);
      _syncController(timeoutController, draft.timeoutSeconds);
      _syncController(connectTimeoutController, draft.connectTimeoutSeconds);
      return null;
    }, <Object?>[draft]);

    final notifier = ref.read(llmSettingsProvider.notifier);
    final spacing = context.appSpacing;
    final fieldsEnabled = settings.fieldsEnabled;
    final autovalidateMode =
        settings.showValidation
            ? AutovalidateMode.always
            : AutovalidateMode.disabled;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LlmSettingsCopy.sharedUsageDescription,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.md),
          Text(
            '启用状态',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.xs),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  key: const Key('llm-enabled-button'),
                  label: '启用',
                  variant: AppButtonVariant.secondary,
                  isSelected: draft.enabled,
                  onPressed:
                      fieldsEnabled
                          ? () => notifier.updateDraft(
                            draft.copyWith(enabled: true),
                          )
                          : null,
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: AppButton(
                  key: const Key('llm-disabled-button'),
                  label: '停用',
                  variant: AppButtonVariant.secondary,
                  isSelected: !draft.enabled,
                  onPressed:
                      fieldsEnabled
                          ? () => notifier.updateDraft(
                            draft.copyWith(enabled: false),
                          )
                          : null,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('llm-base-url-field'),
            controller: baseUrlController,
            focusNode: baseUrlFocusNode,
            label: 'Base URL',
            hintText: '请输入 http/https 地址',
            helperText: LlmSettingsCopy.baseUrlHelperText,
            enabled: fieldsEnabled,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            autovalidateMode: autovalidateMode,
            validator: llmBaseUrlError,
            onChanged:
                (value) => notifier.updateDraft(draft.copyWith(baseUrl: value)),
          ),
          SizedBox(height: spacing.md),
          AppPasswordField(
            fieldKey: const Key('llm-api-key-field'),
            visibilityButtonKey: const Key('llm-api-key-visibility-button'),
            controller: apiKeyController,
            focusNode: apiKeyFocusNode,
            label: 'API Key',
            hintText: '可为空',
            enabled: fieldsEnabled,
            textInputAction: TextInputAction.next,
            showLabel: '显示 API Key',
            hideLabel: '隐藏 API Key',
            onChanged:
                (value) => notifier.updateDraft(draft.copyWith(apiKey: value)),
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('llm-model-field'),
            controller: modelController,
            focusNode: modelFocusNode,
            label: '模型',
            hintText: LlmSettingsCopy.modelHintText,
            helperText: LlmSettingsCopy.modelRecommendationText,
            enabled: fieldsEnabled,
            textInputAction: TextInputAction.next,
            autovalidateMode: autovalidateMode,
            validator: llmModelError,
            onChanged:
                (value) => notifier.updateDraft(draft.copyWith(model: value)),
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('llm-timeout-field'),
            controller: timeoutController,
            focusNode: timeoutFocusNode,
            label: '请求超时（秒）',
            hintText: '请输入正数',
            enabled: fieldsEnabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            autovalidateMode: autovalidateMode,
            validator: (value) => llmTimeoutError(value, label: '请求超时'),
            onChanged:
                (value) =>
                    notifier.updateDraft(draft.copyWith(timeoutSeconds: value)),
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('llm-connect-timeout-field'),
            controller: connectTimeoutController,
            focusNode: connectTimeoutFocusNode,
            label: '连接超时（秒）',
            hintText: '请输入正数',
            enabled: fieldsEnabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            autovalidateMode: autovalidateMode,
            validator: (value) => llmTimeoutError(value, label: '连接超时'),
            onChanged:
                (value) => notifier.updateDraft(
                  draft.copyWith(connectTimeoutSeconds: value),
                ),
          ),
        ],
      ),
    );
  }
}

class _LlmSettingsFooter extends StatelessWidget {
  const _LlmSettingsFooter({
    required this.settings,
    required this.onTest,
    required this.onSave,
  });

  final LlmSettingsState settings;
  final Future<void> Function() onTest;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final maxButtonWidth = context.appLayoutTokens.filterFieldWidthXl;
    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        border: Border(top: BorderSide(color: context.appColors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxButtonWidth),
              child: AppButton(
                key: const Key('llm-test-button'),
                label: '测试配置',
                isLoading: settings.isTesting,
                onPressed: settings.isSaving ? null : onTest,
              ),
            ),
          ),
          SizedBox(width: spacing.md),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxButtonWidth),
              child: AppButton(
                key: const Key('llm-save-button'),
                label: '保存配置',
                variant: AppButtonVariant.primary,
                isLoading: settings.isSaving,
                onPressed: settings.isTesting ? null : onSave,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LlmSettingsError extends StatelessWidget {
  const _LlmSettingsError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return AppContentCard(
      key: const Key('llm-error-state'),
      title: 'LLM 配置加载失败',
      child: AppEmptyState(
        message: message,
        retryKey: const Key('llm-retry-button'),
        onRetry: () => unawaited(onRetry()),
      ),
    );
  }
}

class _LlmSettingsSkeleton extends StatelessWidget {
  const _LlmSettingsSkeleton();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      children: [
        AppSkeletonBlock(
          width: double.infinity,
          height: spacing.xxxl + spacing.xxxl + spacing.xl,
          radius: context.appRadius.lgBorder,
        ),
        SizedBox(height: spacing.md),
        AppSkeletonBlock(
          width: double.infinity,
          height: spacing.xxxl * 4 + spacing.xxl,
          radius: context.appRadius.lgBorder,
        ),
      ],
    );
  }
}

void _syncController(TextEditingController controller, String value) {
  if (controller.text == value) {
    return;
  }
  controller.value = controller.value.copyWith(
    text: value,
    selection: TextSelection.collapsed(offset: value.length),
    composing: TextRange.empty,
  );
}
