import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';

class CatalogSearchField extends StatelessWidget {
  const CatalogSearchField({
    super.key,
    this.fieldKey,
    this.searchButtonKey,
    this.imageSearchButtonKey,
    this.onlineToggleKey,
    required this.controller,
    required this.hintText,
    this.onSubmitted,
    this.onSearchTap,
    this.onImageSearchTap,
    this.showImageSearchButton = false,
    this.showOnlineToggle = false,
    this.isOnlineSearchEnabled = false,
    this.onOnlineSearchToggle,
    this.autofocus = false,
    this.compact = false,
  });

  final Key? fieldKey;
  final Key? searchButtonKey;
  final Key? imageSearchButtonKey;
  final Key? onlineToggleKey;
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onSearchTap;
  final VoidCallback? onImageSearchTap;
  final bool showImageSearchButton;
  final bool showOnlineToggle;
  final bool isOnlineSearchEnabled;
  final ValueChanged<bool>? onOnlineSearchToggle;
  final bool autofocus;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final spacing = context.appSpacing;

    return Container(
      decoration: BoxDecoration(
        color: colors.sidebarActiveBackground,
        borderRadius: context.appRadius.smBorder,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: compact ? spacing.sm : spacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: fieldKey,
              controller: controller,
              autofocus: autofocus,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.normal,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.normal,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (showImageSearchButton) ...[
            AppIconButton(
              key: imageSearchButtonKey,
              iconColor: colors.textPrimary,
              icon: const Icon(Icons.image_search_outlined),
              onPressed: onImageSearchTap,
            ),
          ],
          if (showOnlineToggle) ...[
            AppIconButton(
              key: onlineToggleKey,
              icon: const Icon(Icons.public_rounded),
              isSelected: isOnlineSearchEnabled,
              onPressed:
                  onOnlineSearchToggle == null
                      ? null
                      : () => onOnlineSearchToggle!(!isOnlineSearchEnabled),
            ),
          ],
          AppIconButton(
            key: searchButtonKey,
            iconColor: colors.textPrimary,
            icon: const Icon(Icons.search_rounded),
            onPressed: onSearchTap,
          ),
        ],
      ),
    );
  }
}
