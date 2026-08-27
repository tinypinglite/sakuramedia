import 'package:flutter/material.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_password_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

/// Provider 配置表单的本地控制器。
///
/// 控制器只负责字段输入生命周期和把输入投影为 `provider_config`。它不会
/// 解释配置值，也不会把不存在于 Provider 目录的字段发送给后端。
class ProviderConfigFormController {
  ProviderConfigFormController({
    required List<ProviderConfigFieldDto> fields,
    Map<String, dynamic> initialConfig = const <String, dynamic>{},
  }) : fields = List<ProviderConfigFieldDto>.unmodifiable(fields),
       controllers = <String, TextEditingController>{
         for (final field in fields)
           field.key: TextEditingController(
             text: _initialText(initialConfig[field.key]),
           ),
       };

  final List<ProviderConfigFieldDto> fields;
  final Map<String, TextEditingController> controllers;

  TextEditingController controllerFor(String key) {
    final controller = controllers[key];
    if (controller == null) {
      throw ArgumentError.value(key, 'key', 'Provider 配置字段不存在');
    }
    return controller;
  }

  /// 创建时读取表单值。
  ///
  /// 空的 required secret 会保留为空字符串，由表单校验或后端返回必填错误；
  /// 只读字段始终不提交。
  Map<String, dynamic> toCreateProviderConfig() {
    return _toProviderConfig(omitEmptySecrets: false);
  }

  /// 编辑时读取表单值。
  ///
  /// 空的 secret 表示「沿用服务端已有值」，因此省略该 key；只读字段始终不
  /// 提交，由后端负责保留原值。
  Map<String, dynamic> toUpdateProviderConfig() {
    return _toProviderConfig(omitEmptySecrets: true);
  }

  Map<String, dynamic> _toProviderConfig({required bool omitEmptySecrets}) {
    final result = <String, dynamic>{};
    for (final field in fields) {
      if (field.readOnly) {
        continue;
      }
      final value = controllerFor(field.key).text;
      if (field.isSecret && omitEmptySecrets && value.trim().isEmpty) {
        continue;
      }
      result[field.key] = value;
    }
    return result;
  }

  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }
}

/// 由 Provider 目录驱动的配置字段表单。
///
/// 只映射当前协议中的 `text`、`secret`、`path` 三种输入。创建表单传
/// [isEditing] 为 false，required secret 为空时会校验失败；编辑表单传 true，
/// 空 secret 表示沿用服务端值。
class ProviderConfigFormFields extends StatelessWidget {
  const ProviderConfigFormFields({
    super.key,
    required this.controller,
    this.enabled = true,
    this.autovalidateMode,
    this.isEditing = false,
    this.focusNodes = const <String, FocusNode>{},
    this.fieldSpacing,
  });

  final ProviderConfigFormController controller;
  final bool enabled;
  final AutovalidateMode? autovalidateMode;
  final bool isEditing;
  final Map<String, FocusNode> focusNodes;
  final double? fieldSpacing;

  @override
  Widget build(BuildContext context) {
    final spacing = fieldSpacing ?? context.appSpacing.lg;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < controller.fields.length; index++) ...[
          if (index > 0) SizedBox(height: spacing),
          _buildField(context, controller.fields[index]),
        ],
      ],
    );
  }

  Widget _buildField(BuildContext context, ProviderConfigFieldDto field) {
    final fieldController = controller.controllerFor(field.key);
    final fieldFocusNode = focusNodes[field.key];
    final fieldEnabled = enabled && !field.readOnly;
    final validator = field.required && !field.readOnly
        ? (String? value) =>
              _validateRequired(field, value, isEditing: isEditing)
        : null;
    final fieldKey = Key('provider-config-field-${field.key}');
    final multiline = field.multiline;

    if (field.isSecret) {
      return AppPasswordField(
        fieldKey: fieldKey,
        controller: fieldController,
        focusNode: fieldFocusNode,
        label: field.label,
        hintText: field.hint,
        helperText: field.description,
        enabled: fieldEnabled,
        validator: validator,
        autovalidateMode: autovalidateMode,
      );
    }

    return AppTextField(
      fieldKey: fieldKey,
      controller: fieldController,
      focusNode: fieldFocusNode,
      label: field.label,
      hintText: field.hint,
      helperText: field.description,
      enabled: fieldEnabled,
      validator: validator,
      autovalidateMode: autovalidateMode,
      maxLines: multiline ? 4 : 1,
      minLines: multiline ? 2 : null,
      keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
    );
  }
}

String? _validateRequired(
  ProviderConfigFieldDto field,
  String? value, {
  required bool isEditing,
}) {
  if (field.isSecret && isEditing) {
    return null;
  }
  if (value == null || value.trim().isEmpty) {
    return '请输入${field.label}';
  }
  return null;
}

String _initialText(Object? value) {
  return value is String ? value : '';
}
