import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_switch.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

const _mobileJobParamsHeightFactor = 0.82;

Future<Map<String, dynamic>?> showJobParamsDialog(
  BuildContext context, {
  required JobMetadataDto job,
}) {
  final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
  return showAppAdaptiveModal<Map<String, dynamic>>(
    context: context,
    modalKey: const Key('activity-job-params-dialog'),
    desktopWidth: context.appLayoutTokens.dialogWidthMd,
    mobileHeightFactor: _mobileJobParamsHeightFactor,
    builder: (_) => KeyedSubtree(
      key: const Key('activity-job-params-dialog-content'),
      child: _JobParamsDialog(job: job, isMobile: isMobile),
    ),
  );
}

class _JobParamsDialog extends StatefulWidget {
  const _JobParamsDialog({required this.job, required this.isMobile});

  final JobMetadataDto job;
  final bool isMobile;

  @override
  State<_JobParamsDialog> createState() => _JobParamsDialogState();
}

class _JobParamsDialogState extends State<_JobParamsDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Map<String, dynamic> _values = <String, dynamic>{};
  late final List<_JobParamDefinition> _fields;

  @override
  void initState() {
    super.initState();
    _fields = _buildDefinitions(widget.job.paramsSchema ?? const {});
    for (final field in _fields) {
      final defaultValue = field.defaultValue;
      switch (field.kind) {
        case _JobParamKind.string:
        case _JobParamKind.integer:
        case _JobParamKind.number:
        case _JobParamKind.json:
          _controllers[field.name] = TextEditingController(
            text: _textForDefault(field, defaultValue),
          );
        case _JobParamKind.boolean:
          _values[field.name] = defaultValue is bool ? defaultValue : false;
        case _JobParamKind.optionalBoolean:
        case _JobParamKind.enumValue:
          _values[field.name] = defaultValue;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    if (widget.isMobile) {
      return _buildMobileDrawer(context, spacing);
    }
    return _buildDesktopContent(context, spacing);
  }

  Widget _buildMobileDrawer(BuildContext context, AppSpacing spacing) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final availableHeight =
        (screenHeight - MediaQuery.viewInsetsOf(context).bottom)
            .clamp(0.0, screenHeight)
            .toDouble();
    final drawerHeight = (screenHeight * _mobileJobParamsHeightFactor)
        .clamp(0.0, availableHeight)
        .toDouble();
    final contentHeight = (drawerHeight - spacing.lg * 2)
        .clamp(0.0, drawerHeight)
        .toDouble();

    return SizedBox(
      height: contentHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, spacing),
          SizedBox(height: spacing.lg),
          Expanded(
            child: SingleChildScrollView(
              key: const Key('activity-job-params-form-scroll'),
              child: _buildForm(context),
            ),
          ),
          SizedBox(height: spacing.xl),
          _buildActions(context, spacing),
        ],
      ),
    );
  }

  Widget _buildDesktopContent(BuildContext context, AppSpacing spacing) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, spacing),
        SizedBox(height: spacing.lg),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: SingleChildScrollView(child: _buildForm(context)),
        ),
        SizedBox(height: spacing.xl),
        _buildActions(context, spacing),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, AppSpacing spacing) {
    return Padding(
      padding: EdgeInsets.only(right: spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '填写任务参数',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s18,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            widget.job.cliHelp.isEmpty
                ? widget.job.taskKey
                : widget.job.cliHelp,
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

  Widget _buildForm(BuildContext context) {
    final spacing = context.appSpacing;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_fields.isEmpty)
            Text(
              '该任务没有可填写的参数，将按默认配置执行。',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            )
          else
            for (var index = 0; index < _fields.length; index++) ...[
              _buildField(context, _fields[index]),
              if (index != _fields.length - 1) SizedBox(height: spacing.md),
            ],
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, AppSpacing spacing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AppButton(
          key: const Key('activity-job-params-cancel-button'),
          label: '取消',
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(),
        ),
        SizedBox(width: spacing.sm),
        AppButton(
          key: const Key('activity-job-params-submit-button'),
          label: '提交任务',
          size: AppButtonSize.small,
          variant: AppButtonVariant.primary,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _buildField(BuildContext context, _JobParamDefinition field) {
    final label = '${field.label}${field.required ? ' *' : ''}';
    final helperText = field.description ?? '参数名：${field.name}';
    switch (field.kind) {
      case _JobParamKind.string:
      case _JobParamKind.integer:
      case _JobParamKind.number:
      case _JobParamKind.json:
        return AppTextField(
          fieldKey: Key('activity-job-param-${field.name}'),
          controller: _controllers[field.name],
          label: label,
          helperText: helperText,
          hintText: field.kind == _JobParamKind.json ? '{ ... }' : null,
          keyboardType: switch (field.kind) {
            _JobParamKind.integer => const TextInputType.numberWithOptions(
              signed: true,
            ),
            _JobParamKind.number => const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            _ => null,
          },
          minLines: field.kind == _JobParamKind.json ? 4 : null,
          maxLines: field.kind == _JobParamKind.json ? 6 : 1,
          validator: (_) => _validateTextField(field),
        );
      case _JobParamKind.boolean:
        return _buildBooleanField(
          context,
          field,
          label: label,
          helperText: helperText,
        );
      case _JobParamKind.optionalBoolean:
        return AppSelectField<bool?>(
          key: Key('activity-job-param-${field.name}'),
          label: label,
          value: _values[field.name] as bool?,
          placeholder: '未设置',
          items: const <DropdownMenuItem<bool?>>[
            DropdownMenuItem<bool?>(value: null, child: Text('未设置')),
            DropdownMenuItem<bool?>(value: true, child: Text('是')),
            DropdownMenuItem<bool?>(value: false, child: Text('否')),
          ],
          onChanged: (value) => setState(() => _values[field.name] = value),
        );
      case _JobParamKind.enumValue:
        return AppSelectField<dynamic>(
          key: Key('activity-job-param-${field.name}'),
          label: label,
          value: _values[field.name],
          placeholder: field.required ? '请选择' : '未设置',
          items: [
            if (!field.required)
              const DropdownMenuItem<dynamic>(value: null, child: Text('未设置')),
            ...field.enumValues.map(
              (value) => DropdownMenuItem<dynamic>(
                value: value,
                child: Text(_displayValue(value)),
              ),
            ),
          ],
          validator: field.required
              ? (value) => value == null ? '请选择${field.label}' : null
              : null,
          onChanged: (value) => setState(() => _values[field.name] = value),
        );
    }
  }

  Widget _buildBooleanField(
    BuildContext context,
    _JobParamDefinition field, {
    required String label,
    required String helperText,
  }) {
    final textStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s14,
      weight: AppTextWeight.regular,
      tone: AppTextTone.primary,
    );
    final helperStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.muted,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: textStyle),
              SizedBox(height: context.appSpacing.xs),
              Text(helperText, style: helperStyle),
            ],
          ),
        ),
        SizedBox(width: context.appSpacing.md),
        Padding(
          padding: EdgeInsets.only(top: context.appSpacing.xs),
          child: AppSwitch(
            key: Key('activity-job-param-${field.name}'),
            value: _values[field.name] as bool? ?? false,
            onChanged: (value) => setState(() => _values[field.name] = value),
          ),
        ),
      ],
    );
  }

  String? _validateTextField(_JobParamDefinition field) {
    final value = _controllers[field.name]?.text.trim() ?? '';
    if (value.isEmpty) {
      return field.required ? '请输入${field.label}' : null;
    }
    switch (field.kind) {
      case _JobParamKind.integer:
        return int.tryParse(value) == null ? '请输入整数' : null;
      case _JobParamKind.number:
        return double.tryParse(value) == null ? '请输入数字' : null;
      case _JobParamKind.json:
        try {
          final decoded = jsonDecode(value);
          if (field.type == 'array' && decoded is! List) {
            return '请输入 JSON 数组';
          }
          if (field.type == 'object' && decoded is! Map) {
            return '请输入 JSON 对象';
          }
        } on FormatException {
          return '请输入合法的 JSON';
        }
        return null;
      case _JobParamKind.string:
      case _JobParamKind.boolean:
      case _JobParamKind.optionalBoolean:
      case _JobParamKind.enumValue:
        return null;
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final payload = <String, dynamic>{};
    for (final field in _fields) {
      switch (field.kind) {
        case _JobParamKind.string:
          final value = _controllers[field.name]!.text;
          if (value.trim().isNotEmpty) {
            payload[field.name] = value.trim();
          }
        case _JobParamKind.integer:
          final value = _controllers[field.name]!.text.trim();
          if (value.isNotEmpty) {
            payload[field.name] = int.parse(value);
          }
        case _JobParamKind.number:
          final value = _controllers[field.name]!.text.trim();
          if (value.isNotEmpty) {
            payload[field.name] = double.parse(value);
          }
        case _JobParamKind.json:
          final value = _controllers[field.name]!.text.trim();
          if (value.isNotEmpty) {
            payload[field.name] = jsonDecode(value);
          }
        case _JobParamKind.boolean:
          payload[field.name] = _values[field.name] as bool? ?? false;
        case _JobParamKind.optionalBoolean:
        case _JobParamKind.enumValue:
          final value = _values[field.name];
          if (value != null) {
            payload[field.name] = value;
          }
      }
    }
    Navigator.of(context).pop(payload);
  }
}

enum _JobParamKind {
  string,
  integer,
  number,
  boolean,
  optionalBoolean,
  enumValue,
  json,
}

class _JobParamDefinition {
  const _JobParamDefinition({
    required this.name,
    required this.schema,
    required this.required,
    required this.kind,
  });

  final String name;
  final Map<String, dynamic> schema;
  final bool required;
  final _JobParamKind kind;

  String get label {
    final title = schema['title'];
    if (title is String && title.trim().isNotEmpty) {
      return title.trim();
    }
    return _humanizeName(name);
  }

  String? get description {
    final value = schema['description'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  dynamic get defaultValue => schema['default'];

  String? get type => _resolveSchemaType(schema);

  List<dynamic> get enumValues {
    final value = schema['enum'];
    return value is List ? List<dynamic>.from(value) : const <dynamic>[];
  }
}

List<_JobParamDefinition> _buildDefinitions(Map<String, dynamic> schema) {
  final properties = asMapOrNull(schema['properties']);
  if (properties == null) {
    return const <_JobParamDefinition>[];
  }
  final requiredNames = <String>{
    if (schema['required'] is List)
      ...(schema['required'] as List).whereType<String>(),
  };
  return [
    for (final entry in properties.entries)
      if (asMapOrNull(entry.value) case final property?)
        _JobParamDefinition(
          name: entry.key,
          schema: property,
          required: requiredNames.contains(entry.key),
          kind: _resolveKind(property, requiredNames.contains(entry.key)),
        ),
  ];
}

_JobParamKind _resolveKind(Map<String, dynamic> schema, bool required) {
  final enumValues = schema['enum'];
  if (enumValues is List && enumValues.isNotEmpty) {
    return _JobParamKind.enumValue;
  }
  final type = _resolveSchemaType(schema);
  if (type == 'boolean') {
    final defaultValue = schema['default'];
    if (!required && defaultValue is! bool) {
      return _JobParamKind.optionalBoolean;
    }
    return _JobParamKind.boolean;
  }
  return switch (type) {
    'string' => _JobParamKind.string,
    'integer' => _JobParamKind.integer,
    'number' => _JobParamKind.number,
    _ => _JobParamKind.json,
  };
}

String? _resolveSchemaType(Map<String, dynamic> schema) {
  final directType = schema['type'];
  if (directType is String && directType != 'null') {
    return directType;
  }
  for (final key in const <String>['anyOf', 'oneOf']) {
    final variants = schema[key];
    if (variants is! List) {
      continue;
    }
    for (final variant in variants) {
      final variantMap = asMapOrNull(variant);
      final variantType = variantMap?['type'];
      if (variantType is String && variantType != 'null') {
        return variantType;
      }
    }
  }
  if (schema['properties'] is Map) {
    return 'object';
  }
  return null;
}

String _textForDefault(_JobParamDefinition field, dynamic value) {
  if (value == null) {
    return '';
  }
  if (field.kind == _JobParamKind.json) {
    try {
      return jsonEncode(value);
    } on JsonUnsupportedObjectError {
      return '';
    }
  }
  return value.toString();
}

String _displayValue(dynamic value) {
  if (value == null) {
    return '未设置';
  }
  if (value is bool) {
    return value ? '是' : '否';
  }
  return value.toString();
}

String _humanizeName(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
