import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_switch.dart';
import 'package:sakuramedia/widgets/base/forms/app_password_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

/// 渲染宿主支持的插件配置协议，不依赖具体插件。
class PluginSettingsForm extends StatefulWidget {
  const PluginSettingsForm({
    super.key,
    required this.schema,
    required this.values,
    required this.enabled,
    this.fieldErrors = const {},
    this.onEdited,
  });

  final Map<String, dynamic> schema;
  final Map<String, dynamic> values;
  final bool enabled;
  final Map<String, String> fieldErrors;
  final VoidCallback? onEdited;

  @override
  State<PluginSettingsForm> createState() => _PluginSettingsFormState();
}

class _PluginSettingsFormState extends State<PluginSettingsForm> {
  final _controllers = <String, TextEditingController>{};

  @override
  void didUpdateWidget(covariant PluginSettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.values, widget.values)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      for (final entry in _controllers.entries) {
        dynamic value = widget.values;
        for (final part in entry.key.split('.')) {
          value = value is Map ? value[part] : null;
        }
        final text = value is List ? value.join('\n') : value?.toString() ?? '';
        if (entry.value.text != text) {
          entry.value.text = text;
        }
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _buildObject(widget.schema, widget.values, '');

  Widget _buildObject(
    Map<String, dynamic> schema,
    Map<String, dynamic> values,
    String path,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry
            in (schema['properties'] as Map<String, dynamic>).entries)
          if ((entry.value as Map)['x-hidden'] != true)
            Padding(
              padding: EdgeInsets.only(bottom: context.appSpacing.lg),
              child: _buildField(
                entry.key,
                entry.value,
                values,
                path.isEmpty ? entry.key : '$path.${entry.key}',
                (schema['required'] as List? ?? []).contains(entry.key),
              ),
            ),
      ],
    );
  }

  Widget _description(Widget child, String? description) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      child,
      if (description != null) ...[
        SizedBox(height: context.appSpacing.xs),
        Text(
          description,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
      ],
    ],
  );

  Widget _buildField(
    String name,
    Map<String, dynamic> field,
    Map<String, dynamic> values,
    String path,
    bool required,
  ) {
    final l10n = AppLocalizations.of(context);
    final title = '${field['title'] ?? name}${required ? ' *' : ''}';
    final description = field['description'] as String?;
    final value = values[name];
    final nullable = field['nullable'] == true;
    final type = field['type'];
    final key = Key('plugin-setting-$path');
    String? error() => widget.fieldErrors[path];
    void change(dynamic next) {
      setState(() => values[name] = next);
      widget.onEdited?.call();
    }

    if (type == 'object') {
      // 已保存的对象类型错误时允许用户从字段重新填写。
      final nested = value is Map<String, dynamic>
          ? value
          : <String, dynamic>{};
      values[name] = nested;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _description(
            Text(
              title,
              softWrap: true,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s16,
                weight: AppTextWeight.semibold,
              ),
            ),
            description,
          ),
          SizedBox(height: context.appSpacing.md),
          _buildObject(field, nested, path),
        ],
      );
    }
    final choices = field['enum'] as List?;
    if (choices != null || (type == 'boolean' && nullable)) {
      final options = <dynamic>[
        if (nullable) null,
        ...?choices,
        if (choices == null) ...[false, true],
      ];
      final index = options.indexOf(value);
      return _description(
        AppSelectField<int>(
          key: key,
          label: title,
          value: index < 0 ? null : index,
          items: [
            for (var i = 0; i < options.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(
                  options[i] == null
                      ? l10n.pluginSettingsUnset
                      : type == 'boolean'
                      ? (options[i] == true
                            ? l10n.pluginSettingsOn
                            : l10n.pluginSettingsOff)
                      : options[i].toString(),
                ),
              ),
          ],
          validator: (_) =>
              error() ??
              (options.contains(values[name])
                  ? null
                  : l10n.pluginSettingsSelectOne),
          onChanged: widget.enabled
              ? (i) {
                  if (i != null) change(options[i]);
                }
              : null,
        ),
        description,
      );
    }
    if (type == 'boolean') {
      return FormField<bool>(
        validator: (_) =>
            error() ??
            (values[name] is bool ? null : l10n.pluginSettingsSelectToggle),
        builder: (state) => _description(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  softWrap: true,
                  style: resolveAppTextStyle(context, size: AppTextSize.s14),
                ),
              ),
              SizedBox(width: context.appSpacing.sm),
              Semantics(
                label: title,
                child: AppSwitch(
                  key: key,
                  value: values[name] == true,
                  onChanged: widget.enabled ? change : null,
                ),
              ),
            ],
          ),
          state.errorText ?? description,
        ),
      );
    }
    final number = type == 'integer' || type == 'number';
    final list = type == 'array';
    final controller = _controllers.putIfAbsent(
      path,
      () => TextEditingController(
        text: list && value is List
            ? value.join('\n')
            : value?.toString() ?? '',
      ),
    );
    String? validate(String? text) {
      if (error() != null) return error();
      final input = text ?? '';
      dynamic parsed;
      if (input.isEmpty && nullable) {
        parsed = null;
      } else if (number) {
        parsed = type == 'integer' ? int.tryParse(input) : num.tryParse(input);
        if (parsed == null || !(parsed as num).isFinite) {
          return type == 'integer'
              ? l10n.pluginSettingsInteger
              : l10n.pluginSettingsNumber;
        }
        final minimum = field['minimum'] as num?;
        final maximum = field['maximum'] as num?;
        final exclusiveMin = field['exclusiveMinimum'] as num?;
        final exclusiveMax = field['exclusiveMaximum'] as num?;
        if (minimum != null && parsed < minimum) {
          return l10n.pluginSettingsMin('$minimum');
        }
        if (maximum != null && parsed > maximum) {
          return l10n.pluginSettingsMax('$maximum');
        }
        if (exclusiveMin != null && parsed <= exclusiveMin) {
          return l10n.pluginSettingsExclusiveMin('$exclusiveMin');
        }
        if (exclusiveMax != null && parsed >= exclusiveMax) {
          return l10n.pluginSettingsExclusiveMax('$exclusiveMax');
        }
      } else if (list) {
        parsed = input
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
      } else {
        parsed = input;
        if (required && input.isEmpty) {
          return l10n.pluginSettingsRequired(title);
        }
        final min = field['minLength'] as int?;
        final max = field['maxLength'] as int?;
        if (min != null && input.runes.length < min) {
          return l10n.pluginSettingsMinLength(min);
        }
        if (max != null && input.runes.length > max) {
          return l10n.pluginSettingsMaxLength(max);
        }
      }
      values[name] = parsed;
      return null;
    }

    final bounds = [
      if (field['minimum'] != null)
        l10n.pluginSettingsBoundMin('${field['minimum']}'),
      if (field['exclusiveMinimum'] != null)
        l10n.pluginSettingsBoundGreater('${field['exclusiveMinimum']}'),
      if (field['maximum'] != null)
        l10n.pluginSettingsBoundMax('${field['maximum']}'),
      if (field['exclusiveMaximum'] != null)
        l10n.pluginSettingsBoundLess('${field['exclusiveMaximum']}'),
    ].join(l10n.listSeparator);
    final helper = [
      if (description != null) description,
      if (list) l10n.pluginSettingsListHint,
      if (number && bounds.isNotEmpty) bounds,
      if (nullable && description == null) l10n.pluginSettingsNullableHint,
    ].join(l10n.hintSeparator);
    if (field['format'] == 'password' || field['writeOnly'] == true) {
      return AppPasswordField(
        fieldKey: key,
        controller: controller,
        label: title,
        helperText: helper.isEmpty ? null : helper,
        enabled: widget.enabled,
        validator: validate,
        onChanged: (_) => widget.onEdited?.call(),
      );
    }
    final multiline = list || field['x-multiline'] == true;
    return AppTextField(
      fieldKey: key,
      controller: controller,
      label: title,
      helperText: helper.isEmpty ? null : helper,
      enabled: widget.enabled,
      minLines: multiline ? 3 : 1,
      maxLines: multiline ? 5 : 1,
      keyboardType: number
          ? TextInputType.numberWithOptions(
              decimal: type == 'number',
              signed: true,
            )
          : multiline
          ? TextInputType.multiline
          : TextInputType.text,
      validator: validate,
      onChanged: (_) => widget.onEdited?.call(),
    );
  }
}
