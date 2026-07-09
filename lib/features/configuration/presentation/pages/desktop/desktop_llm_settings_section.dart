import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/configuration/data/api/movie_desc_translation_settings_api.dart';
import 'package:sakuramedia/features/configuration/presentation/controllers/llm_settings_controller.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/llm_settings_copy.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/llm_settings_form_fields.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';

class DesktopLlmSettingsSection extends StatefulWidget {
  const DesktopLlmSettingsSection({super.key, required this.active});

  final bool active;

  @override
  State<DesktopLlmSettingsSection> createState() =>
      _DesktopLlmSettingsSectionState();
}

class _DesktopLlmSettingsSectionState extends State<DesktopLlmSettingsSection> {
  late final LlmSettingsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LlmSettingsController(
      api: context.read<MovieDescTranslationSettingsApi>(),
    );
    if (widget.active) {
      unawaited(_controller.load());
    }
  }

  @override
  void didUpdateWidget(covariant DesktopLlmSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active &&
        !_controller.initialized &&
        !_controller.isLoading) {
      unawaited(_controller.load());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (!_controller.initialized && !widget.active) {
          return const SizedBox.shrink();
        }
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
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.isLoading) {
      return const _DesktopLlmSkeleton();
    }
    if (_controller.errorMessage != null) {
      return _DesktopLlmErrorState(
        message: _controller.errorMessage!,
        onRetry: _controller.load,
      );
    }

    final spacing = context.appSpacing;
    final enabled = _controller.enabled;
    final busy = !_controller.fieldsEnabled;

    return Form(
      key: _controller.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  LlmSettingsCopy.sharedUsageDescription,
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
                label: enabled ? '已启用' : '已停用',
                tone: enabled ? AppBadgeTone.success : AppBadgeTone.warning,
                size: AppBadgeSize.compact,
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Text(
            LlmSettingsCopy.sharedEndpointDescription,
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
                value: enabled ? '已启用' : '已停用',
              ),
              _DesktopLlmOverviewStat(
                label: '配置完整度',
                value: _controller.hasCompleteConfig ? '可保存' : '待补齐',
              ),
              _DesktopLlmOverviewStat(
                label: '最近测试',
                value: _controller.testStateLabel,
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
                  isSelected: enabled,
                  onPressed: busy ? null : () => _controller.updateEnabled(true),
                ),
              ),
              SizedBox(width: spacing.sm),
              SizedBox(
                width: 180,
                child: AppButton(
                  key: const Key('configuration-llm-disabled-button'),
                  label: '已停用',
                  variant: AppButtonVariant.secondary,
                  isSelected: !enabled,
                  onPressed:
                      busy ? null : () => _controller.updateEnabled(false),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.lg),
          LlmSettingsFormFields(
            controller: _controller,
            keyPrefix: 'configuration-llm',
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
                  isLoading: _controller.isTesting,
                  onPressed: _controller.isSaving ? null : _controller.runTest,
                ),
              ),
              SizedBox(width: spacing.md),
              SizedBox(
                width: 220,
                child: AppButton(
                  key: const Key('configuration-llm-save-button'),
                  label: '保存配置',
                  variant: AppButtonVariant.primary,
                  isLoading: _controller.isSaving,
                  onPressed: _controller.isTesting ? null : _controller.save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
