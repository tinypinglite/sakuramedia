import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/configuration/data/api/movie_desc_translation_settings_api.dart';
import 'package:sakuramedia/features/configuration/presentation/controllers/llm_settings_controller.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/llm_settings_copy.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/llm_settings_form_fields.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/app_shell/app_badge.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/app_shell/app_mobile_notice_card.dart';
import 'package:sakuramedia/widgets/feedback/app_mobile_skeleton.dart';

class MobileLlmSettingsPage extends StatefulWidget {
  const MobileLlmSettingsPage({super.key});

  @override
  State<MobileLlmSettingsPage> createState() => _MobileLlmSettingsPageState();
}

class _MobileLlmSettingsPageState extends State<MobileLlmSettingsPage> {
  late final LlmSettingsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LlmSettingsController(
      api: context.read<MovieDescTranslationSettingsApi>(),
    );
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ColoredBox(
          key: const Key('mobile-settings-llm'),
          color: colors.surfaceCard,
          child: Column(
            children: [
              Expanded(
                child: AppAdaptiveRefreshScrollView(
                  onRefresh: _controller.refresh,
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
              if (_controller.errorMessage == null) _buildFooterBar(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooterBar(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.all(spacing.md),
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
              isLoading: _controller.isTesting,
              onPressed: _controller.isSaving ? null : _controller.runTest,
            ),
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: AppButton(
              key: const Key('mobile-llm-save-button'),
              label: '保存配置',
              variant: AppButtonVariant.primary,
              isLoading: _controller.isSaving,
              onPressed: _controller.isTesting ? null : _controller.save,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.isLoading) {
      return const _MobileLlmLoadingSection();
    }
    if (_controller.errorMessage != null) {
      return _MobileLlmErrorSection(
        message: _controller.errorMessage!,
        onRetry: _controller.load,
      );
    }

    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppMobileNoticeCard(
          key: const Key('mobile-llm-overview-card'),
          title: '先确认服务地址和模型，再决定是否启用，并可直接用当前草稿发起测试。',
          description: LlmSettingsCopy.sharedEndpointDescription,
          stats: [
            AppMobileNoticeStat(
              label: '启用状态',
              value: _controller.enabled ? '已启用' : '已停用',
            ),
            AppMobileNoticeStat(
              label: '配置完整度',
              value: _controller.hasCompleteConfig ? '可保存' : '待补齐',
            ),
            AppMobileNoticeStat(
              label: '最近测试',
              value: _controller.testStateLabel,
            ),
          ],
        ),
        SizedBox(height: spacing.md),
        _buildFormCard(context),
      ],
    );
  }

  Widget _buildFormCard(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final enabled = _controller.enabled;
    final busy = !_controller.fieldsEnabled;

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
        key: _controller.formKey,
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
                  label: enabled ? '已启用' : '已停用',
                  tone: enabled ? AppBadgeTone.success : AppBadgeTone.warning,
                  size: AppBadgeSize.compact,
                ),
              ],
            ),
            SizedBox(height: spacing.xs),
            Text(
              LlmSettingsCopy.sharedUsageDescription,
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
                    isSelected: enabled,
                    onPressed:
                        busy ? null : () => _controller.updateEnabled(true),
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: AppButton(
                    key: const Key('mobile-llm-disabled-button'),
                    label: '已停用',
                    variant: AppButtonVariant.secondary,
                    isSelected: !enabled,
                    onPressed:
                        busy ? null : () => _controller.updateEnabled(false),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.md),
            LlmSettingsFormFields(
              controller: _controller,
              keyPrefix: 'mobile-llm',
            ),
          ],
        ),
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
        AppSkeletonBlock(
          width: double.infinity,
          height: context.appSpacing.xxl * 3.4,
          radius: context.appRadius.lgBorder,
        ),
        SizedBox(height: context.appSpacing.md),
        AppSkeletonBlock(
          width: double.infinity,
          height: context.appSpacing.xxl * 5.8,
          radius: context.appRadius.lgBorder,
        ),
      ],
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
      child: AppEmptyState(
        message: message,
        retryKey: const Key('mobile-llm-retry-button'),
        onRetry: () => unawaited(onRetry()),
      ),
    );
  }
}
