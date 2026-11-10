import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_switch.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_action_row.dart';

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
          _buildActions(context),
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
        _buildActions(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, AppSpacing spacing) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(right: spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.activityJobParamsTitle,
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
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_fields.isEmpty)
            Text(
              l10n.activityJobParamsEmpty,
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

  Widget _buildActions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppModalActionRow(
      submitKey: const Key('activity-job-params-submit-button'),
      submitLabel: l10n.activityJobParamsSubmit,
      showCancel: false,
      equalWidth: widget.isMobile,
      onSubmit: _submit,
    );
  }

  Widget _buildField(BuildContext context, _JobParamDefinition field) {
    final l10n = AppLocalizations.of(context);
    final label = '${field.label}${field.required ? ' *' : ''}';
    final helperText =
        field.description ?? l10n.activityJobParamFallbackHelp(field.name);
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
          placeholder: l10n.activityJobParamUnset,
          items: <DropdownMenuItem<bool?>>[
            DropdownMenuItem<bool?>(
              value: null,
              child: Text(l10n.activityJobParamUnset),
            ),
            DropdownMenuItem<bool?>(
              value: true,
              child: Text(l10n.activityJobParamYes),
            ),
            DropdownMenuItem<bool?>(
              value: false,
              child: Text(l10n.activityJobParamNo),
            ),
          ],
          onChanged: (value) => setState(() => _values[field.name] = value),
        );
      case _JobParamKind.enumValue:
        final options = _visibleOptions(field);
        return AppSelectField<dynamic>(
          key: Key('activity-job-param-${field.name}'),
          label: label,
          value: _values[field.name],
          placeholder: field.required
              ? l10n.activityJobParamSelectPlaceholder
              : l10n.activityJobParamUnset,
          items: [
            if (!field.required)
              DropdownMenuItem<dynamic>(
                value: null,
                child: Text(l10n.activityJobParamUnset),
              ),
            ...options.map(
              (option) => DropdownMenuItem<dynamic>(
                value: option.value,
                child: Text(option.label ?? _displayValue(option.value, l10n)),
              ),
            ),
          ],
          validator: field.required
              ? (value) => value == null
                    ? l10n.activityJobParamSelectRequired(field.label)
                    : null
              : null,
          onChanged: (value) => _setValue(field.name, value),
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

  dynamic _currentValue(String name) {
    if (_values.containsKey(name)) {
      return _values[name];
    }
    return _controllers[name]?.text.trim();
  }

  List<_JobParamOption> _visibleOptions(_JobParamDefinition field) {
    final options = field.options;
    final parentName = field.optionsDependOn;
    if (parentName == null) {
      return options;
    }
    final parentValue = _currentValue(parentName);
    if (parentValue == null || parentValue == '') {
      return options;
    }
    return [
      for (final option in options)
        if (option.when.isEmpty || option.when.contains(parentValue)) option,
    ];
  }

  void _setValue(String name, dynamic value) {
    setState(() {
      _values[name] = value;
      for (final field in _fields) {
        if (field.optionsDependOn != name) {
          continue;
        }
        final current = _values[field.name];
        if (current == null) {
          continue;
        }
        final visibleValues = _visibleOptions(
          field,
        ).map((option) => option.value);
        if (!visibleValues.contains(current)) {
          _values[field.name] = null;
        }
      }
    });
  }

  String? _validateTextField(_JobParamDefinition field) {
    final l10n = AppLocalizations.of(context);
    final value = _controllers[field.name]?.text.trim() ?? '';
    if (value.isEmpty) {
      return field.required ? l10n.activityJobParamRequired(field.label) : null;
    }
    switch (field.kind) {
      case _JobParamKind.integer:
        return int.tryParse(value) == null
            ? l10n.activityJobParamIntegerRequired
            : null;
      case _JobParamKind.number:
        return double.tryParse(value) == null
            ? l10n.activityJobParamNumberRequired
            : null;
      case _JobParamKind.json:
        try {
          final decoded = jsonDecode(value);
          if (field.type == 'array' && decoded is! List) {
            return l10n.activityJobParamJsonArrayRequired;
          }
          if (field.type == 'object' && decoded is! Map) {
            return l10n.activityJobParamJsonObjectRequired;
          }
        } on FormatException {
          return l10n.activityJobParamJsonInvalid;
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

  List<_JobParamOption> get options => _parseOptions(schema);

  String? get optionsDependOn {
    final value = schema['x-options-by'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }
}

class _JobParamOption {
  const _JobParamOption({
    required this.value,
    this.label,
    this.when = const <String>[],
  });

  final dynamic value;
  final String? label;
  final List<String> when;
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

List<_JobParamOption> _parseOptions(Map<String, dynamic> schema) {
  final oneOf = schema['oneOf'];
  if (oneOf is List) {
    final options = <_JobParamOption>[];
    for (final entry in oneOf) {
      final entryMap = asMapOrNull(entry);
      if (entryMap == null || !entryMap.containsKey('const')) {
        return const <_JobParamOption>[];
      }
      final title = entryMap['title'];
      options.add(
        _JobParamOption(
          value: entryMap['const'],
          label: title is String && title.trim().isNotEmpty
              ? title.trim()
              : null,
          when: _stringList(entryMap['x-when']),
        ),
      );
    }
    return options;
  }
  final enumValues = schema['enum'];
  if (enumValues is List) {
    return [for (final value in enumValues) _JobParamOption(value: value)];
  }
  return const <_JobParamOption>[];
}

List<String> _stringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return [
    for (final item in value)
      if (item is String && item.isNotEmpty) item,
  ];
}

_JobParamKind _resolveKind(Map<String, dynamic> schema, bool required) {
  if (_parseOptions(schema).isNotEmpty) {
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

String _displayValue(dynamic value, AppLocalizations l10n) {
  if (value == null) {
    return l10n.activityJobParamUnset;
  }
  if (value is bool) {
    return value ? l10n.activityJobParamYes : l10n.activityJobParamNo;
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
