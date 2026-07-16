import 'package:sakuramedia/core/validation/url_validators.dart';
import 'package:sakuramedia/features/configuration/data/dto/movie_desc_translation_settings_dto.dart';

enum LlmConfigTestState { idle, success, failure }

class LlmSettingsDraft {
  const LlmSettingsDraft({
    required this.enabled,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.timeoutSeconds,
    required this.connectTimeoutSeconds,
  });

  factory LlmSettingsDraft.fromDto(MovieDescTranslationSettingsDto dto) {
    return LlmSettingsDraft(
      enabled: dto.enabled,
      baseUrl: dto.baseUrl,
      apiKey: dto.apiKey,
      model: dto.model,
      timeoutSeconds: formatLlmNumber(dto.timeoutSeconds),
      connectTimeoutSeconds: formatLlmNumber(dto.connectTimeoutSeconds),
    );
  }

  final bool enabled;
  final String baseUrl;
  final String apiKey;
  final String model;
  final String timeoutSeconds;
  final String connectTimeoutSeconds;

  LlmSettingsDraft copyWith({
    bool? enabled,
    String? baseUrl,
    String? apiKey,
    String? model,
    String? timeoutSeconds,
    String? connectTimeoutSeconds,
  }) {
    return LlmSettingsDraft(
      enabled: enabled ?? this.enabled,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      connectTimeoutSeconds:
          connectTimeoutSeconds ?? this.connectTimeoutSeconds,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LlmSettingsDraft &&
            enabled == other.enabled &&
            baseUrl == other.baseUrl &&
            apiKey == other.apiKey &&
            model == other.model &&
            timeoutSeconds == other.timeoutSeconds &&
            connectTimeoutSeconds == other.connectTimeoutSeconds;
  }

  @override
  int get hashCode => Object.hash(
    enabled,
    baseUrl,
    apiKey,
    model,
    timeoutSeconds,
    connectTimeoutSeconds,
  );
}

class LlmSettingsState {
  const LlmSettingsState({
    required this.saved,
    required this.draft,
    this.isSaving = false,
    this.isTesting = false,
    this.showValidation = false,
    this.testState = LlmConfigTestState.idle,
  });

  factory LlmSettingsState.fromDto(MovieDescTranslationSettingsDto dto) {
    final draft = LlmSettingsDraft.fromDto(dto);
    return LlmSettingsState(saved: draft, draft: draft);
  }

  final LlmSettingsDraft saved;
  final LlmSettingsDraft draft;
  final bool isSaving;
  final bool isTesting;
  final bool showValidation;
  final LlmConfigTestState testState;

  bool get isDirty => saved != draft;
  bool get fieldsEnabled => !isSaving && !isTesting;
  bool get hasCompleteConfig => isValidLlmDraft(draft);

  String get testStateLabel => switch (testState) {
    LlmConfigTestState.idle => '未测试',
    LlmConfigTestState.success => '测试通过',
    LlmConfigTestState.failure => '测试失败',
  };

  LlmSettingsState copyWith({
    LlmSettingsDraft? saved,
    LlmSettingsDraft? draft,
    bool? isSaving,
    bool? isTesting,
    bool? showValidation,
    LlmConfigTestState? testState,
  }) {
    return LlmSettingsState(
      saved: saved ?? this.saved,
      draft: draft ?? this.draft,
      isSaving: isSaving ?? this.isSaving,
      isTesting: isTesting ?? this.isTesting,
      showValidation: showValidation ?? this.showValidation,
      testState: testState ?? this.testState,
    );
  }
}

bool isValidLlmDraft(LlmSettingsDraft draft) {
  return llmBaseUrlError(draft.baseUrl) == null &&
      llmModelError(draft.model) == null &&
      llmTimeoutError(draft.timeoutSeconds, label: '请求超时') == null &&
      llmTimeoutError(draft.connectTimeoutSeconds, label: '连接超时') == null;
}

String? llmBaseUrlError(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty || !isValidHttpUrl(trimmed)) {
    return '请输入合法的 http/https 地址';
  }
  return null;
}

String? llmModelError(String? value) {
  if ((value?.trim() ?? '').isEmpty) {
    return '请输入模型名称';
  }
  return null;
}

String? llmTimeoutError(String? value, {required String label}) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return '请输入$label';
  }
  final parsed = double.tryParse(trimmed);
  if (parsed == null || parsed <= 0) {
    return '$label必须是正数';
  }
  return null;
}

String formatLlmNumber(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
