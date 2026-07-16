import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/api/movie_desc_translation_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/movie_desc_translation_settings_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/llm_settings_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/llm_settings_state.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late _FakeLlmSettingsApi api;
  late ProviderContainer container;

  setUp(() {
    sessionStore = SessionStore.inMemory();
    apiClient = ApiClient(sessionStore: sessionStore);
    api = _FakeLlmSettingsApi(apiClient: apiClient);
    container = ProviderContainer(
      overrides: [llmSettingsApiProvider.overrideWithValue(api)],
      retry: (_, __) => null,
    );
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  test('build loads settings into saved and draft', () async {
    api.getHandler = () async => _settings(enabled: true);

    final state = await container.read(llmSettingsProvider.future);

    expect(state.saved, state.draft);
    expect(state.draft.enabled, isTrue);
    expect(state.draft.baseUrl, 'https://llm.example.com');
    expect(state.isDirty, isFalse);
    expect(api.getCalls, 1);
  });

  test('build failure is exposed and reload can recover', () async {
    api.getHandler = () async => throw Exception('load failed');

    await expectLater(
      container.read(llmSettingsProvider.future),
      throwsA(isA<Exception>()),
    );

    api.getHandler = () async => _settings(model: 'recovered-model');
    await container.read(llmSettingsProvider.notifier).reload();

    expect(_state(container).draft.model, 'recovered-model');
    expect(api.getCalls, 2);
  });

  test('draft update marks dirty and clears previous test result', () async {
    api.getHandler = () async => _settings();
    api.testHandler = (_) async => true;
    await container.read(llmSettingsProvider.future);
    final notifier = container.read(llmSettingsProvider.notifier);
    await notifier.runConnectionTest();

    notifier.updateDraft(_state(container).draft.copyWith(model: 'new-model'));

    final state = _state(container);
    expect(state.isDirty, isTrue);
    expect(state.testState, LlmConfigTestState.idle);
  });

  test(
    'invalid draft enables validation and does not call mutations',
    () async {
      api.getHandler = () async => _settings();
      await container.read(llmSettingsProvider.future);
      final notifier = container.read(llmSettingsProvider.notifier);
      notifier.updateDraft(
        _state(container).draft.copyWith(
          baseUrl: 'invalid',
          model: '',
          timeoutSeconds: '0',
          connectTimeoutSeconds: '-1',
        ),
      );

      expect(await notifier.save(), isNull);
      expect(await notifier.runConnectionTest(), isNull);

      expect(_state(container).showValidation, isTrue);
      expect(api.updateCalls, 0);
      expect(api.testCalls, 0);
    },
  );

  test('save sends trimmed payload and applies returned settings', () async {
    api.getHandler = () async => _settings();
    api.updateHandler =
        (payload) async => _settings(
          enabled: true,
          baseUrl: payload.baseUrl,
          model: 'normalized-model',
          timeoutSeconds: payload.timeoutSeconds,
          connectTimeoutSeconds: payload.connectTimeoutSeconds,
        );
    await container.read(llmSettingsProvider.future);
    final notifier = container.read(llmSettingsProvider.notifier);
    notifier.updateDraft(
      _state(container).draft.copyWith(
        enabled: true,
        baseUrl: ' https://draft.example.com ',
        model: ' draft-model ',
        timeoutSeconds: '120',
        connectTimeoutSeconds: '5',
      ),
    );

    expect(await notifier.save(), 'LLM 配置已保存');

    final payload = api.lastUpdatePayload!;
    expect(payload.baseUrl, 'https://draft.example.com');
    expect(payload.model, 'draft-model');
    expect(payload.timeoutSeconds, 120);
    expect(_state(container).draft.model, 'normalized-model');
    expect(_state(container).isDirty, isFalse);
  });

  test('save failure keeps draft and clears saving state', () async {
    api.getHandler = () async => _settings();
    api.updateHandler = (_) async => throw Exception('save failed');
    await container.read(llmSettingsProvider.future);
    final notifier = container.read(llmSettingsProvider.notifier);
    notifier.updateDraft(
      _state(container).draft.copyWith(model: 'unsaved-model'),
    );

    expect(await notifier.save(), contains('保存 LLM 配置失败'));

    expect(_state(container).draft.model, 'unsaved-model');
    expect(_state(container).isSaving, isFalse);
    expect(_state(container).isDirty, isTrue);
  });

  test('connection test handles false and thrown errors', () async {
    api.getHandler = () async => _settings();
    api.testHandler = (_) async => false;
    await container.read(llmSettingsProvider.future);
    final notifier = container.read(llmSettingsProvider.notifier);

    expect(await notifier.runConnectionTest(), '测试失败');
    expect(_state(container).testState, LlmConfigTestState.failure);

    api.testHandler = (_) async => throw Exception('test failed');
    expect(await notifier.runConnectionTest(), contains('测试 LLM 配置失败'));
    expect(_state(container).testState, LlmConfigTestState.failure);
  });

  test('save and connection test are mutually exclusive', () async {
    final saveCompleter = Completer<MovieDescTranslationSettingsDto>();
    api.getHandler = () async => _settings();
    api.updateHandler = (_) => saveCompleter.future;
    await container.read(llmSettingsProvider.future);
    final notifier = container.read(llmSettingsProvider.notifier);

    final saveFuture = notifier.save();
    expect(_state(container).isSaving, isTrue);
    expect(await notifier.runConnectionTest(), isNull);
    expect(api.testCalls, 0);

    saveCompleter.complete(_settings());
    await saveFuture;
  });

  test('refresh failure preserves current data', () async {
    api.getHandler = () async => _settings(model: 'current-model');
    await container.read(llmSettingsProvider.future);
    api.getHandler = () async => throw Exception('refresh failed');

    expect(
      await container.read(llmSettingsProvider.notifier).refresh(),
      contains('LLM 配置加载失败'),
    );

    expect(_state(container).draft.model, 'current-model');
  });

  test('async mutation completion is safe after container disposal', () async {
    final saveCompleter = Completer<MovieDescTranslationSettingsDto>();
    api.getHandler = () async => _settings();
    api.updateHandler = (_) => saveCompleter.future;
    await container.read(llmSettingsProvider.future);

    final saveFuture = container.read(llmSettingsProvider.notifier).save();
    container.dispose();
    saveCompleter.complete(_settings());

    expect(await saveFuture, isNull);
  });
}

LlmSettingsState _state(ProviderContainer container) {
  return container.read(llmSettingsProvider).requireValue;
}

MovieDescTranslationSettingsDto _settings({
  bool enabled = false,
  String baseUrl = 'https://llm.example.com',
  String apiKey = '',
  String model = 'gpt-test',
  double timeoutSeconds = 300,
  double connectTimeoutSeconds = 3,
}) {
  return MovieDescTranslationSettingsDto(
    enabled: enabled,
    baseUrl: baseUrl,
    apiKey: apiKey,
    model: model,
    timeoutSeconds: timeoutSeconds,
    connectTimeoutSeconds: connectTimeoutSeconds,
  );
}

class _FakeLlmSettingsApi extends MovieDescTranslationSettingsApi {
  _FakeLlmSettingsApi({required super.apiClient});

  Future<MovieDescTranslationSettingsDto> Function()? getHandler;
  Future<MovieDescTranslationSettingsDto> Function(
    UpdateMovieDescTranslationSettingsPayload payload,
  )?
  updateHandler;
  Future<bool> Function(TestMovieDescTranslationSettingsPayload payload)?
  testHandler;

  int getCalls = 0;
  int updateCalls = 0;
  int testCalls = 0;
  UpdateMovieDescTranslationSettingsPayload? lastUpdatePayload;

  @override
  Future<MovieDescTranslationSettingsDto> getSettings() {
    getCalls += 1;
    return getHandler!();
  }

  @override
  Future<MovieDescTranslationSettingsDto> updateSettings(
    UpdateMovieDescTranslationSettingsPayload payload,
  ) {
    updateCalls += 1;
    lastUpdatePayload = payload;
    return updateHandler!(payload);
  }

  @override
  Future<bool> testSettings(TestMovieDescTranslationSettingsPayload payload) {
    testCalls += 1;
    return testHandler!(payload);
  }
}
