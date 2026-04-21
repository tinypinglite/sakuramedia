import 'package:flutter/material.dart';
import 'package:sakuramedia/features/configuration/data/media_library_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

typedef MediaLibraryFieldLabelBuilder =
    Widget Function(BuildContext context, String label);

class MediaLibraryFormValue {
  const MediaLibraryFormValue({required this.name, required this.rootPath});

  factory MediaLibraryFormValue.fromControllers({
    required TextEditingController nameController,
    required TextEditingController rootPathController,
  }) {
    return MediaLibraryFormValue(
      name: nameController.text.trim(),
      rootPath: rootPathController.text.trim(),
    );
  }

  final String name;
  final String rootPath;

  CreateMediaLibraryPayload toCreatePayload() {
    return CreateMediaLibraryPayload(name: name, rootPath: rootPath);
  }

  UpdateMediaLibraryPayload toUpdatePayload() {
    return UpdateMediaLibraryPayload(name: name, rootPath: rootPath);
  }
}

String? validateMediaLibraryName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '请输入媒体库名称';
  }
  return null;
}

String? validateMediaLibraryRootPath(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '请输入媒体库根路径';
  }
  if (!isAbsoluteMediaLibraryPath(value.trim())) {
    return '请输入路径';
  }
  return null;
}

bool isAbsoluteMediaLibraryPath(String value) {
  if (value.startsWith('/')) {
    return true;
  }
  return RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value);
}

class MediaLibraryFormFields extends StatelessWidget {
  const MediaLibraryFormFields({
    super.key,
    required this.nameController,
    required this.rootPathController,
    this.nameFocusNode,
    this.rootPathFocusNode,
    this.onRootPathSubmitted,
    this.enabled = true,
    this.autovalidateMode,
    this.labelBuilder,
    this.nameFieldKey = const Key('media-library-name-field'),
    this.rootPathFieldKey = const Key('media-library-root-path-field'),
    this.fieldSpacing,
  });

  final TextEditingController nameController;
  final TextEditingController rootPathController;
  final FocusNode? nameFocusNode;
  final FocusNode? rootPathFocusNode;
  final ValueChanged<String>? onRootPathSubmitted;
  final bool enabled;
  final AutovalidateMode? autovalidateMode;
  final MediaLibraryFieldLabelBuilder? labelBuilder;
  final Key nameFieldKey;
  final Key rootPathFieldKey;
  final double? fieldSpacing;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final resolvedFieldSpacing = fieldSpacing ?? spacing.md;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._buildField(
          context,
          label: '名称',
          field: AppTextField(
            fieldKey: nameFieldKey,
            controller: nameController,
            focusNode: nameFocusNode,
            enabled: enabled,
            label: labelBuilder == null ? '名称' : null,
            hintText: '例如: Main Library',
            validator: validateMediaLibraryName,
            autovalidateMode: autovalidateMode,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => rootPathFocusNode?.requestFocus(),
          ),
        ),
        SizedBox(height: resolvedFieldSpacing),
        ..._buildField(
          context,
          label: '根路径',
          field: AppTextField(
            fieldKey: rootPathFieldKey,
            controller: rootPathController,
            focusNode: rootPathFocusNode,
            enabled: enabled,
            label: labelBuilder == null ? '根路径' : null,
            hintText: '填映射到容器内的路径，例如: /mnt/medialibray1',
            validator: validateMediaLibraryRootPath,
            autovalidateMode: autovalidateMode,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: onRootPathSubmitted,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildField(
    BuildContext context, {
    required String label,
    required Widget field,
  }) {
    final builder = labelBuilder;
    if (builder == null) {
      return <Widget>[field];
    }
    return <Widget>[
      builder(context, label),
      SizedBox(height: context.appSpacing.sm),
      field,
    ];
  }
}
