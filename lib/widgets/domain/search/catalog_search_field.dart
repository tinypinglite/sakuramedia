import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

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

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      fieldKey: fieldKey,
      controller: controller,
      hintText: hintText,
      textInputAction: TextInputAction.search,
      onFieldSubmitted: onSubmitted,
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showImageSearchButton)
            AppIconButton(
              key: imageSearchButtonKey,
              iconColor: context.appTextPalette.primary,
              icon: const Icon(Icons.image_search_outlined),
              onPressed: onImageSearchTap,
            ),
          if (showOnlineToggle)
            AppIconButton(
              key: onlineToggleKey,
              icon: const Icon(Icons.public_rounded),
              isSelected: isOnlineSearchEnabled,
              onPressed:
                  onOnlineSearchToggle == null
                      ? null
                      : () => onOnlineSearchToggle!(!isOnlineSearchEnabled),
            ),
          AppIconButton(
            key: searchButtonKey,
            iconColor: context.appTextPalette.primary,
            icon: const Icon(Icons.search_rounded),
            onPressed: onSearchTap,
          ),
        ],
      ),
    );
  }
}
