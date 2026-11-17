import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_error_dto.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/api/download_selection_policy_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_selection_policy_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_selection_policy_api_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_selection_policy_provider.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

void main() {
  test('loads policy, tracks draft and saves expected version', () async {
    final context = await _context();
    addTearDown(context.dispose);

    final state = await context.container.read(
      downloadSelectionPolicyProvider.future,
    );
    expect(state.saved.version, 2);
    expect(state.draft.minSeeders, 1);

    final notifier = context.container.read(
      downloadSelectionPolicyProvider.notifier,
    );
    notifier.updateDraft(state.draft.copyWith(minSeeders: 4));
    expect(
      context.container
          .read(downloadSelectionPolicyProvider)
          .requireValue
          .isDirty,
      isTrue,
    );
    notifier.discardDraft();
    expect(
      context.container
          .read(downloadSelectionPolicyProvider)
          .requireValue
          .isDirty,
      isFalse,
    );
    notifier.updateDraft(state.draft.copyWith(minSeeders: 4));

    expect(await notifier.save(), isTrue);
    expect(context.api.lastExpectedVersion, 2);
    expect(context.api.lastSavedRules?.minSeeders, 4);
    expect(
      context.container
          .read(downloadSelectionPolicyProvider)
          .requireValue
          .saved
          .version,
      3,
    );
  });

  test('version conflict keeps the draft and exposes conflict state', () async {
    final context = await _context();
    addTearDown(context.dispose);
    final state = await context.container.read(
      downloadSelectionPolicyProvider.future,
    );
    final notifier = context.container.read(
      downloadSelectionPolicyProvider.notifier,
    );
    notifier.updateDraft(state.draft.copyWith(minSeeders: 7));
    context.api.updateError = const ApiException(
      statusCode: 409,
      message: 'conflict',
      error: ApiErrorDto(
        code: 'download_selection_policy_version_conflict',
        message: 'conflict',
      ),
    );

    expect(await notifier.save(), isFalse);
    final latest = context.container
        .read(downloadSelectionPolicyProvider)
        .requireValue;
    expect(latest.hasVersionConflict, isTrue);
    expect(latest.draft.minSeeders, 7);
    expect(latest.saved.version, 2);
  });

  test('preview ignores an older response after the draft changes', () async {
    final context = await _context();
    addTearDown(context.dispose);
    final state = await context.container.read(
      downloadSelectionPolicyProvider.future,
    );
    final notifier = context.container.read(
      downloadSelectionPolicyProvider.notifier,
    );
    final first = Completer<DownloadSelectionPreviewDto>();
    final second = Completer<DownloadSelectionPreviewDto>();
    context.api.previewCompleters.addAll(
      <Completer<DownloadSelectionPreviewDto>>[first, second],
    );

    final firstFuture = notifier.preview('ABC-001');
    notifier.updateDraft(state.draft.copyWith(minSeeders: 2));
    final secondFuture = notifier.preview('ABC-002');

    second.complete(_preview(movieNumber: 'ABC-002', rawCount: 2));
    await secondFuture;
    first.complete(_preview(movieNumber: 'ABC-001', rawCount: 1));
    await firstFuture;

    final preview = context.container
        .read(downloadSelectionPolicyProvider)
        .requireValue
        .preview;
    expect(preview?.rawCandidateCount, 2);
  });

  test(
    'preview sends the normalized number and keeps the original input',
    () async {
      final context = await _context();
      addTearDown(context.dispose);
      await context.container.read(downloadSelectionPolicyProvider.future);
      final notifier = context.container.read(
        downloadSelectionPolicyProvider.notifier,
      );

      await notifier.preview('ABP-123', inputMovieNumber: 'abp123');

      final state = context.container
          .read(downloadSelectionPolicyProvider)
          .requireValue;
      expect(context.api.lastPreviewMovieNumber, 'ABP-123');
      expect(state.previewMovieNumber, 'abp123');
    },
  );
}

Future<_ProviderContext> _context() async {
  final store = SessionStore.inMemory();
  await store.saveBaseUrl('https://api.example.com');
  await store.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-03-08T10:00:00Z'),
  );
  final apiClient = ApiClient(sessionStore: store);
  final api = _FakeDownloadSelectionPolicyApi(apiClient: apiClient);
  final container = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(store),
      appLocalizationsProvider.overrideWithValue(AppLocalizationsZh()),
      downloadSelectionPolicyApiProvider.overrideWithValue(api),
    ],
    retry: (_, _) => null,
  );
  return _ProviderContext(store, apiClient, api, container);
}

class _ProviderContext {
  const _ProviderContext(this.store, this.apiClient, this.api, this.container);

  final SessionStore store;
  final ApiClient apiClient;
  final _FakeDownloadSelectionPolicyApi api;
  final ProviderContainer container;

  void dispose() {
    container.dispose();
    apiClient.dispose();
    store.dispose();
  }
}

class _FakeDownloadSelectionPolicyApi extends DownloadSelectionPolicyApi {
  _FakeDownloadSelectionPolicyApi({required super.apiClient});

  int? lastExpectedVersion;
  DownloadSelectionRulesDto? lastSavedRules;
  Object? updateError;
  final List<Completer<DownloadSelectionPreviewDto>> previewCompleters =
      <Completer<DownloadSelectionPreviewDto>>[];
  String? lastPreviewMovieNumber;
  int _previewIndex = 0;

  @override
  Future<DownloadSelectionPolicyDto> getPolicy() async => _policy(version: 2);

  @override
  Future<DownloadSelectionPolicyDto> updatePolicy({
    required int expectedVersion,
    required DownloadSelectionRulesDto rules,
  }) async {
    final error = updateError;
    if (error != null) throw error;
    lastExpectedVersion = expectedVersion;
    lastSavedRules = rules;
    return _policy(version: expectedVersion + 1, rules: rules);
  }

  @override
  Future<DownloadSelectionPreviewDto> preview({
    required String movieNumber,
    required DownloadSelectionRulesDto rules,
  }) async {
    lastPreviewMovieNumber = movieNumber;
    final index = _previewIndex++;
    if (index < previewCompleters.length) {
      return previewCompleters[index].future;
    }
    return _preview(movieNumber: movieNumber, rawCount: 2);
  }
}

DownloadSelectionPolicyDto _policy({
  required int version,
  DownloadSelectionRulesDto rules = const DownloadSelectionRulesDto(),
}) {
  return DownloadSelectionPolicyDto(
    rules: rules,
    version: version,
    createdAt: DateTime.parse('2026-10-29T12:00:00Z'),
    updatedAt: DateTime.parse('2026-10-30T12:00:00Z'),
  );
}

DownloadSelectionPreviewDto _preview({
  required String movieNumber,
  required int rawCount,
}) {
  return DownloadSelectionPreviewDto(
    draft: true,
    policyVersion: null,
    rawCandidateCount: rawCount,
    systemCandidateCount: rawCount,
    eligibleCandidateCount: 0,
    policyFilteredCount: rawCount,
    rejectionCounts: const <String, int>{},
    selectedSourceUri: null,
    candidates: const <DownloadCandidateDto>[],
  );
}
