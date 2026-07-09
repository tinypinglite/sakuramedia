import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class AppPageFrame extends StatelessWidget {
  const AppPageFrame({
    super.key,
    required this.title,
    this.eyebrow,
    this.description,
    this.scrollController,
    required this.child,
  });

  final String title;
  final String? eyebrow;
  final String? description;
  final ScrollController? scrollController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasEyebrow = eyebrow != null && eyebrow!.isNotEmpty;
    final hasTitle = title.isNotEmpty;
    final hasDescription = description != null && description!.isNotEmpty;
    final hasHeader = hasEyebrow || hasTitle || hasDescription;

    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasEyebrow) ...[
            Text(
              eyebrow!,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.muted,
              ),
            ),
            SizedBox(height: context.appSpacing.sm),
          ],
          if (hasTitle)
            Text(
              title,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s20,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
          if (hasDescription) ...[
            SizedBox(height: context.appSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Text(
                description!,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s16,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
            ),
          ],
          if (hasHeader) SizedBox(height: context.appSpacing.xl),
          child,
        ],
      ),
    );
  }
}
