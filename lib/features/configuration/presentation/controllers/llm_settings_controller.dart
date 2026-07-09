import 'package:flutter/widgets.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/validation/url_validators.dart';
import 'package:sakuramedia/features/configuration/data/api/movie_desc_translation_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/movie_desc_translation_settings_dto.dart';

enum LlmConfigTestState { idle, success, failure }

/// LLM 设置控制器：桌面与移动端 LLM 页共享的业务逻辑与 field controllers。
///
/// 页面持有它、AnimatedBuilder 监听它、dispose 时释放。UI 结构（overview 布局、
/// 启停按钮布局、外壳）由各端自己写，本控制器只管数据与状态。
class LlmSettingsController extends ChangeNotifier {
  LlmSettingsController({required this.api});

  final MovieDescTranslationSettingsApi api;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController baseUrlController = TextEditingController();
  final TextEditingController apiKeyController = TextEditingController();
  final TextEditingController modelController = TextEditingController();
  final TextEditingController timeoutController = TextEditingController();
  final TextEditingController connectTimeoutController = TextEditingController();

  bool _enabled = false;
  bool _initialized = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isTesting = false;
  bool _showValidation = false;
  String? _errorMessage;
  LlmConfigTestState _testState = LlmConfigTestState.idle;
  bool _disposed = false;

  bool get enabled => _enabled;
  bool get initialized => _initialized;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isTesting => _isTesting;
  String? get errorMessage => _errorMessage;
  LlmConfigTestState get testState => _testState;

  bool get hasCompleteConfig {
    return llmBaseUrlError(baseUrlController.text) == null &&
        llmModelError(modelController.text) == null &&
        llmTimeoutError(timeoutController.text, label: '请求超时') == null &&
        llmTimeoutError(connectTimeoutController.text, label: '连接超时') == null;
  }

  AutovalidateMode get autovalidateMode =>
      _showValidation ? AutovalidateMode.always : AutovalidateMode.disabled;

  bool get fieldsEnabled => !_isSaving && !_isTesting;

  String get testStateLabel => switch (_testState) {
    LlmConfigTestState.idle => '未测试',
    LlmConfigTestState.success => '测试通过',
    LlmConfigTestState.failure => '测试失败',
  };

  @override
  void dispose() {
    _disposed = true;
    baseUrlController.dispose();
    apiKeyController.dispose();
    modelController.dispose();
    timeoutController.dispose();
    connectTimeoutController.dispose();
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final settings = await api.getSettings();
      if (_disposed) return;
      _applySettings(settings);
      _initialized = true;
      _testState = LlmConfigTestState.idle;
      _isLoading = false;
    } catch (error) {
      if (_disposed) return;
      _initialized = true;
      _isLoading = false;
      _errorMessage = apiErrorMessage(error, fallback: 'LLM 配置加载失败');
    }
    _safeNotify();
  }

  Future<void> refresh() async {
    try {
      final settings = await api.getSettings();
      if (_disposed) return;
      _applySettings(settings);
      _errorMessage = null;
      _safeNotify();
    } catch (error) {
      if (_disposed) return;
      showToast(apiErrorMessage(error, fallback: 'LLM 配置加载失败'));
    }
  }

  Future<void> save() async {
    final payload = _buildUpdatePayload();
    if (payload == null || _isSaving) return;
    _isSaving = true;
    _safeNotify();
    try {
      final saved = await api.updateSettings(payload);
      if (_disposed) return;
      _applySettings(saved);
      _testState = LlmConfigTestState.idle;
      _isSaving = false;
      _safeNotify();
      showToast('LLM 配置已保存');
    } catch (error) {
      if (_disposed) return;
      _isSaving = false;
      _safeNotify();
      showToast(apiErrorMessage(error, fallback: '保存 LLM 配置失败'));
    }
  }

  Future<void> runTest() async {
    final payload = _buildTestPayload();
    if (payload == null || _isTesting) return;
    _isTesting = true;
    _safeNotify();
    try {
      final ok = await api.testSettings(payload);
      if (_disposed) return;
      _isTesting = false;
      _testState = ok ? LlmConfigTestState.success : LlmConfigTestState.failure;
      _safeNotify();
      showToast(ok ? '测试通过' : '测试失败');
    } catch (error) {
      if (_disposed) return;
      _isTesting = false;
      _testState = LlmConfigTestState.failure;
      _safeNotify();
      showToast(apiErrorMessage(error, fallback: '测试 LLM 配置失败'));
    }
  }

  void updateEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _testState = LlmConfigTestState.idle;
    _safeNotify();
  }

  void handleDraftChanged() {
    if (_testState == LlmConfigTestState.idle) return;
    _testState = LlmConfigTestState.idle;
    _safeNotify();
  }

  void _applySettings(MovieDescTranslationSettingsDto settings) {
    _enabled = settings.enabled;
    baseUrlController.text = settings.baseUrl;
    apiKeyController.text = settings.apiKey;
    modelController.text = settings.model;
    timeoutController.text = _formatNumber(settings.timeoutSeconds);
    connectTimeoutController.text = _formatNumber(
      settings.connectTimeoutSeconds,
    );
    _showValidation = false;
    _errorMessage = null;
  }

  UpdateMovieDescTranslationSettingsPayload? _buildUpdatePayload() {
    if (!_validateForm()) return null;
    return UpdateMovieDescTranslationSettingsPayload(
      enabled: _enabled,
      baseUrl: baseUrlController.text.trim(),
      apiKey: apiKeyController.text,
      model: modelController.text.trim(),
      timeoutSeconds: double.parse(timeoutController.text.trim()),
      connectTimeoutSeconds: double.parse(
        connectTimeoutController.text.trim(),
      ),
    );
  }

  TestMovieDescTranslationSettingsPayload? _buildTestPayload() {
    if (!_validateForm()) return null;
    return TestMovieDescTranslationSettingsPayload(
      enabled: _enabled,
      baseUrl: baseUrlController.text.trim(),
      apiKey: apiKeyController.text,
      model: modelController.text.trim(),
      timeoutSeconds: double.parse(timeoutController.text.trim()),
      connectTimeoutSeconds: double.parse(
        connectTimeoutController.text.trim(),
      ),
    );
  }

  bool _validateForm() {
    _showValidation = true;
    _safeNotify();
    return formKey.currentState?.validate() ?? false;
  }

  String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
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
