/// 将支持的 JSON Schema 子集解析成表单字段，引用仅限本份 schema。
Map<String, dynamic>? pluginFormSchema(Map<String, dynamic> root) {
  Map<String, dynamic>? resolve(Map<String, dynamic> source, Set<String> refs) {
    var field = Map<String, dynamic>.from(source);
    final ref = field.remove(r'$ref');
    if (ref != null) {
      if (ref is! String || !ref.startsWith('#/') || refs.contains(ref)) {
        return null;
      }
      dynamic target = root;
      for (final part in ref.substring(2).split('/')) {
        if (target is! Map) return null;
        target = target[part.replaceAll('~1', '/').replaceAll('~0', '~')];
      }
      if (target is! Map<String, dynamic>) return null;
      final resolved = resolve(target, {...refs, ref});
      if (resolved == null) return null;
      field = {...resolved, ...field};
    }
    final alternatives = field.remove('anyOf');
    if (alternatives != null) {
      if (alternatives is! List || alternatives.length != 2) return null;
      final types = alternatives.whereType<Map<String, dynamic>>().toList();
      if (types.length != 2 ||
          types.where((f) => f['type'] == 'null').length != 1) {
        return null;
      }
      final resolved = resolve(
        types.firstWhere((f) => f['type'] != 'null'),
        refs,
      );
      if (resolved == null ||
          ![
            'string',
            'number',
            'integer',
            'boolean',
          ].contains(resolved['type'])) {
        return null;
      }
      field = {...resolved, ...field, 'nullable': true};
    }
    if (field.containsKey('oneOf') || field.containsKey('allOf')) return null;
    switch (field['type']) {
      case 'object':
        final properties = field['properties'];
        if (properties is! Map<String, dynamic>) return null;
        if (field['additionalProperties'] is Map) return null;
        final children = <String, dynamic>{};
        for (final entry in properties.entries) {
          if (entry.value is! Map<String, dynamic>) return null;
          final child = resolve(entry.value, refs);
          if (child == null) return null;
          children[entry.key] = child;
        }
        field['properties'] = children;
      case 'array':
        if (field['items'] is! Map || field['items']['type'] != 'string') {
          return null;
        }
      case 'string':
      case 'integer':
      case 'number':
      case 'boolean':
        break;
      default:
        return null;
    }
    return field;
  }

  if (root['type'] != 'object') return null;
  return resolve(root, {});
}

/// 按层合并默认值，显式保存的值（包括 null）优先。
Map<String, dynamic> pluginFormValues(
  Map<String, dynamic> schema,
  Map<String, dynamic> defaults,
  Map<String, dynamic> saved,
) {
  final result = <String, dynamic>{...defaults, ...saved};
  for (final entry in (schema['properties'] as Map<String, dynamic>).entries) {
    final field = entry.value as Map<String, dynamic>;
    if (!result.containsKey(entry.key) && field.containsKey('default')) {
      result[entry.key] = field['default'];
    }
    if (field['type'] == 'object') {
      final value = result[entry.key];
      if (value == null || value is Map<String, dynamic>) {
        result[entry.key] = pluginFormValues(
          field,
          defaults[entry.key] is Map<String, dynamic>
              ? defaults[entry.key]
              : {},
          value is Map<String, dynamic> ? value : {},
        );
      }
    }
  }
  return result;
}
