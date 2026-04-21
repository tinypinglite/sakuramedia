import 'package:flutter/material.dart';
import 'package:sakuramedia/features/configuration/data/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/media_library_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

class DownloadClientFormValue {
  const DownloadClientFormValue({
    required this.name,
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.clientSavePath,
    required this.localRootPath,
    required this.mediaLibraryId,
  });

  factory DownloadClientFormValue.fromControllers({
    required TextEditingController nameController,
    required TextEditingController baseUrlController,
    required TextEditingController usernameController,
    required TextEditingController passwordController,
    required TextEditingController clientSavePathController,
    required TextEditingController localRootPathController,
    required int? mediaLibraryId,
  }) {
    return DownloadClientFormValue(
      name: nameController.text.trim(),
      baseUrl: baseUrlController.text.trim(),
      username: usernameController.text.trim(),
      password: passwordController.text.trim(),
      clientSavePath: clientSavePathController.text.trim(),
      localRootPath: localRootPathController.text.trim(),
      mediaLibraryId: mediaLibraryId,
    );
  }

  final String name;
  final String baseUrl;
  final String username;
  final String password;
  final String clientSavePath;
  final String localRootPath;
  final int? mediaLibraryId;

  CreateDownloadClientPayload toCreatePayload() {
    return CreateDownloadClientPayload(
      name: name,
      baseUrl: baseUrl,
      username: username,
      password: password,
      clientSavePath: clientSavePath,
      localRootPath: localRootPath,
      mediaLibraryId: mediaLibraryId!,
    );
  }

  UpdateDownloadClientPayload toUpdatePayload() {
    return UpdateDownloadClientPayload(
      name: name,
      baseUrl: baseUrl,
      username: username,
      password: password.isEmpty ? null : password,
      clientSavePath: clientSavePath,
      localRootPath: localRootPath,
      mediaLibraryId: mediaLibraryId,
    );
  }
}

String? validateDownloadClientName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '请输入下载器名称';
  }
  return null;
}

String? validateDownloadClientBaseUrl(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '请输入服务地址';
  }
  if (!isValidDownloadClientHttpUrl(value.trim())) {
    return '请输入合法的 http/https 地址';
  }
  return null;
}

String? validateDownloadClientUsername(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '请输入用户名';
  }
  return null;
}

String? validateDownloadClientPassword(
  String? value, {
  required bool isEditing,
}) {
  if (isEditing) {
    return null;
  }
  if (value == null || value.trim().isEmpty) {
    return '请输入密码';
  }
  return null;
}

String? validateDownloadClientClientSavePath(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '请输入qBittorrent保存路径';
  }
  if (!isAbsoluteDownloadClientPath(value.trim())) {
    return '请输入路径';
  }
  return null;
}

String? validateDownloadClientLocalRootPath(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '请输入本地访问路径';
  }
  if (!isAbsoluteDownloadClientPath(value.trim())) {
    return '请输入路径';
  }
  return null;
}

bool isValidDownloadClientHttpUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

bool isAbsoluteDownloadClientPath(String value) {
  if (value.startsWith('/')) {
    return true;
  }
  return RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value);
}

class DownloadClientFormFields extends StatelessWidget {
  const DownloadClientFormFields({
    super.key,
    required this.nameController,
    required this.baseUrlController,
    required this.usernameController,
    required this.passwordController,
    required this.clientSavePathController,
    required this.localRootPathController,
    required this.libraries,
    required this.selectedLibraryId,
    required this.onLibraryChanged,
    required this.isEditing,
    this.enabled = true,
    this.autovalidateMode,
    this.nameFocusNode,
    this.baseUrlFocusNode,
    this.usernameFocusNode,
    this.passwordFocusNode,
    this.clientSavePathFocusNode,
    this.localRootPathFocusNode,
    this.credentialsLayout = DownloadClientCredentialsLayout.vertical,
    this.fieldSpacing,
    this.horizontalCredentialsGap,
    this.onSubmitted,
  });

  final TextEditingController nameController;
  final TextEditingController baseUrlController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController clientSavePathController;
  final TextEditingController localRootPathController;
  final List<MediaLibraryDto> libraries;
  final int? selectedLibraryId;
  final ValueChanged<int?> onLibraryChanged;
  final bool isEditing;
  final bool enabled;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? nameFocusNode;
  final FocusNode? baseUrlFocusNode;
  final FocusNode? usernameFocusNode;
  final FocusNode? passwordFocusNode;
  final FocusNode? clientSavePathFocusNode;
  final FocusNode? localRootPathFocusNode;
  final DownloadClientCredentialsLayout credentialsLayout;
  final double? fieldSpacing;
  final double? horizontalCredentialsGap;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final resolvedFieldSpacing = fieldSpacing ?? spacing.lg;
    final credentialsFields = _buildCredentialsFields(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          fieldKey: const Key('download-client-name-field'),
          controller: nameController,
          focusNode: nameFocusNode,
          enabled: enabled,
          label: '名称',
          hintText: '给下载器起个名字，例如：pt 专属',
          validator: validateDownloadClientName,
          autovalidateMode: autovalidateMode,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => baseUrlFocusNode?.requestFocus(),
        ),
        SizedBox(height: resolvedFieldSpacing),
        AppTextField(
          fieldKey: const Key('download-client-base-url-field'),
          controller: baseUrlController,
          focusNode: baseUrlFocusNode,
          enabled: enabled,
          label: '服务地址',
          hintText: '填写完整内网地址，例如：http://192.168.1.2:8080',
          validator: validateDownloadClientBaseUrl,
          autovalidateMode: autovalidateMode,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => usernameFocusNode?.requestFocus(),
        ),
        SizedBox(height: resolvedFieldSpacing),
        credentialsFields,
        SizedBox(height: resolvedFieldSpacing),
        AppTextField(
          fieldKey: const Key('download-client-client-save-path-field'),
          controller: clientSavePathController,
          focusNode: clientSavePathFocusNode,
          enabled: enabled,
          label: 'qBittorrent保存路径',
          hintText: '填写 qBittorrent 容器内使用的路径，例如：/downloads',
          helperText: 'qBittorrent 实际保存文件时使用的路径',
          validator: validateDownloadClientClientSavePath,
          autovalidateMode: autovalidateMode,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => localRootPathFocusNode?.requestFocus(),
        ),
        SizedBox(height: resolvedFieldSpacing),
        AppTextField(
          fieldKey: const Key('download-client-local-root-path-field'),
          controller: localRootPathController,
          focusNode: localRootPathFocusNode,
          enabled: enabled,
          label: '本地访问路径',
          hintText: '填写 SakuraMediaBE 中的实际下载绝对路径，例如:/mnt/downloads',
          helperText: '注意确保和 qBittorrent 的下载路径在宿主机上是同一个路径.',
          validator: validateDownloadClientLocalRootPath,
          autovalidateMode: autovalidateMode,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => onSubmitted?.call(),
        ),
        SizedBox(height: resolvedFieldSpacing),
        AppSelectField<int>(
          key: const Key('download-client-media-library-field'),
          value: selectedLibraryId,
          items: libraries
              .map(
                (library) => DropdownMenuItem<int>(
                  value: library.id,
                  child: Text(library.name),
                ),
              )
              .toList(growable: false),
          label: '目标媒体库',
          placeholder: libraries.isEmpty ? '请先准备媒体库' : '请选择目标媒体库',
          onChanged: enabled && libraries.isNotEmpty ? onLibraryChanged : null,
          validator: (value) => value == null ? '请选择目标媒体库' : null,
        ),
      ],
    );
  }

  Widget _buildCredentialsFields(BuildContext context) {
    final usernameField = AppTextField(
      fieldKey: const Key('download-client-username-field'),
      controller: usernameController,
      focusNode: usernameFocusNode,
      enabled: enabled,
      label: '用户名',
      hintText: '输入用于登录下载器的用户名',
      validator: validateDownloadClientUsername,
      autovalidateMode: autovalidateMode,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => passwordFocusNode?.requestFocus(),
    );
    final passwordField = AppTextField(
      fieldKey: const Key('download-client-password-field'),
      controller: passwordController,
      focusNode: passwordFocusNode,
      enabled: enabled,
      label: '密码',
      hintText: '输入用于登录下载器的密码',
      helperText: isEditing ? '留空则保持原密码不变' : null,
      obscureText: true,
      validator:
          (value) =>
              validateDownloadClientPassword(value, isEditing: isEditing),
      autovalidateMode: autovalidateMode,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => clientSavePathFocusNode?.requestFocus(),
    );

    if (credentialsLayout == DownloadClientCredentialsLayout.horizontal) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: usernameField),
          SizedBox(width: horizontalCredentialsGap ?? context.appSpacing.md),
          Expanded(child: passwordField),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        usernameField,
        SizedBox(height: fieldSpacing ?? context.appSpacing.lg),
        passwordField,
      ],
    );
  }
}

enum DownloadClientCredentialsLayout { vertical, horizontal }
