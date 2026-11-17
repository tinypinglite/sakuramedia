import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_selection_policy_dto.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  group('download selection policy api', () {
    test('getPolicy parses rules, nullable limits and timestamps', () async {
      final bundle = await _bundle();
      addTearDown(bundle.dispose);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/download-selection-policy',
        body: _policyJson(),
      );

      final policy = await bundle.downloadSelectionPolicyApi.getPolicy();

      expect(policy.version, 3);
      expect(policy.rules.indexerKinds, <String>['pt']);
      expect(policy.rules.maxSizeBytes, isNull);
      expect(policy.rules.maxAgeDays, 30);
      expect(
        policy.rules.requiredGroups.single,
        isA<DownloadSelectionKeywordGroupDto>()
            .having((item) => item.label, 'label', '清晰度')
            .having((item) => item.terms, 'terms', <String>['1080p', '2160p']),
      );
      expect(policy.rules.ranking, <DownloadSelectionRanking>[
        DownloadSelectionRanking.seedersDesc,
        DownloadSelectionRanking.indexerPriority,
      ]);
      expect(policy.createdAt, isNotNull);
    });

    test('updatePolicy sends expected version and serialized rules', () async {
      final bundle = await _bundle();
      addTearDown(bundle.dispose);
      bundle.adapter.enqueueJson(
        method: 'PUT',
        path: '/download-selection-policy',
        body: _policyJson(version: 4),
      );
      final rules =
          DownloadSelectionRulesDto.fromJson(
            _policyJson()['rules'] as Map<String, dynamic>,
          ).copyWith(
            indexerKinds: const <String>['pt', 'bt'],
            maxSizeBytes: 20 * 1024 * 1024 * 1024,
            excludedTerms: const <String>['sample'],
          );

      final updated = await bundle.downloadSelectionPolicyApi.updatePolicy(
        expectedVersion: 3,
        rules: rules,
      );

      final request = bundle.adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.body['expected_version'], 3);
      final payloadRules = request.body['rules'] as Map<String, dynamic>;
      expect(payloadRules['indexer_kinds'], <String>['pt', 'bt']);
      expect(payloadRules['max_size_bytes'], 20 * 1024 * 1024 * 1024);
      expect(payloadRules['excluded_terms'], <String>['sample']);
      expect(updated.version, 4);
    });

    test('preview sends draft rules and parses evaluated candidates', () async {
      final bundle = await _bundle();
      addTearDown(bundle.dispose);
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/download-selection-policy/preview',
        body: <String, dynamic>{
          'draft': true,
          'policy_version': null,
          'raw_candidate_count': 3,
          'system_candidate_count': 2,
          'eligible_candidate_count': 1,
          'policy_filtered_count': 1,
          'rejection_counts': <String, int>{'excluded_term': 1},
          'selected_source_uri': 'magnet:?xt=good',
          'candidates': <Map<String, dynamic>>[
            _candidateJson(uri: 'magnet:?xt=good', eligible: true, rank: 1),
          ],
        },
      );

      final preview = await bundle.downloadSelectionPolicyApi.preview(
        movieNumber: 'ABC-001',
        rules: const DownloadSelectionRulesDto(),
      );

      final request = bundle.adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.body['movie_number'], 'ABC-001');
      expect(request.body['rules']['schema_version'], 1);
      expect(preview.draft, isTrue);
      expect(preview.policyVersion, isNull);
      expect(preview.rawCandidateCount, 3);
      expect(preview.selectedSourceUri, 'magnet:?xt=good');
      expect(preview.candidates.single.selectionEvaluation?.selectionRank, 1);
    });
  });
}

Future<TestApiBundle> _bundle() async {
  final sessionStore = SessionStore.inMemory();
  await sessionStore.saveBaseUrl('https://api.example.com');
  await sessionStore.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-03-08T10:00:00Z'),
  );
  return createTestApiBundle(sessionStore);
}

Map<String, dynamic> _policyJson({int version = 3}) {
  return <String, dynamic>{
    'version': version,
    'created_at': '2026-10-29T12:00:00Z',
    'updated_at': '2026-10-30T12:00:00Z',
    'rules': <String, dynamic>{
      'schema_version': 1,
      'indexer_kinds': <String>['pt'],
      'indexer_names': <String>['mteam'],
      'min_size_bytes': 1024 * 1024 * 1024,
      'max_size_bytes': null,
      'min_seeders': 2,
      'max_age_days': 30,
      'match_title': true,
      'match_description': false,
      'required_groups': <Map<String, dynamic>>[
        <String, dynamic>{
          'label': '清晰度',
          'terms': <String>['1080p', '2160p'],
        },
      ],
      'excluded_terms': <String>[],
      'preferred_groups': <Map<String, dynamic>>[],
      'ranking': <String>['seeders_desc', 'indexer_priority'],
      'indexer_priority_names': <String>['mteam'],
    },
  };
}

Map<String, dynamic> _candidateJson({
  required String uri,
  required bool eligible,
  int? rank,
}) {
  return <String, dynamic>{
    'source_uri': uri,
    'indexer_name': 'mteam',
    'indexer_kind': 'pt',
    'resolved_client_id': 1,
    'resolved_client_name': 'qb',
    'download_clients': <Map<String, dynamic>>[],
    'movie_number': 'ABC-001',
    'title': 'ABC-001 1080p',
    'size_bytes': 5368709120,
    'seeders': 10,
    'selection_evaluation': <String, dynamic>{
      'eligible': eligible,
      'rejection_reasons': <Map<String, dynamic>>[],
      'matched_required_group_labels': <String>[],
      'matched_preferred_group_label': null,
      'preference_rank': null,
      'selection_rank': rank,
      'within_attempt_limit': rank != null && rank <= 5,
    },
  };
}
