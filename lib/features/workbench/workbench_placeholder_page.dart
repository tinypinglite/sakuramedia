import 'package:flutter/material.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_content_card.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/app_shell/app_page_frame.dart';

class WorkbenchPlaceholderPage extends StatelessWidget {
  const WorkbenchPlaceholderPage({
    super.key,
    required this.platform,
    required this.title,
    required this.description,
    required this.routePath,
    required this.eyebrow,
    this.showUiKitShowcase = false,
    this.isMinimalOverview = false,
  });

  final AppPlatform platform;
  final String title;
  final String description;
  final String routePath;
  final String eyebrow;
  final bool showUiKitShowcase;
  final bool isMinimalOverview;

  @override
  Widget build(BuildContext context) {
    if (isMinimalOverview) {
      return ColoredBox(
        key: const Key('overview-content-canvas'),
        color: context.appColors.surfaceElevated,
        child: const SizedBox.expand(),
      );
    }

    return AppPageFrame(
      title: title,
      eyebrow: eyebrow,
      description: description,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppContentCard(
            title: '当前阶段目标',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '桌面端工作台骨架',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  '当前页面只提供稳定的壳层占位，后续业务模块将直接替换内容区域，不改路由语义和工作台布局。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: context.appSpacing.md,
                  runSpacing: context.appSpacing.md,
                  children: [
                    _InfoChip(label: '平台', value: _platformLabel(platform)),
                    _InfoChip(label: '路径', value: routePath),
                    _InfoChip(label: '状态', value: 'Skeleton'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (showUiKitShowcase) ...[
            AppContentCard(
              title: '设计令牌预览',
              child: Wrap(
                spacing: context.appSpacing.lg,
                runSpacing: context.appSpacing.lg,
                children: [
                  _TokenSwatch(
                    label: 'Primary',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  _TokenSwatch(
                    label: 'Surface',
                    color: context.appColors.surfacePage,
                  ),
                  _TokenSwatch(
                    label: 'Card',
                    color: context.appColors.surfaceCard,
                  ),
                  _TokenSwatch(
                    label: 'Border',
                    color: context.appColors.borderSubtle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          const AppEmptyState(message: '功能模块待接入'),
        ],
      ),
    );
  }

  String _platformLabel(AppPlatform value) {
    switch (value) {
      case AppPlatform.desktop:
        return 'Desktop';
      case AppPlatform.mobile:
        return 'Mobile';
      case AppPlatform.web:
        return 'Web';
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.md,
        vertical: context.appSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.pillBorder,
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _TokenSwatch extends StatelessWidget {
  const _TokenSwatch({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: color,
              borderRadius: context.appRadius.mdBorder,
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}
