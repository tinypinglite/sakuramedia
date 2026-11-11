import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/discovery/data/taste_profile_dto.dart';

void main() {
  test('fromJson derives the subscribed group and parses recommendations', () {
    final profile = TasteProfileDto.fromJson(_profileJson());

    expect(profile.sampleMovieCount, 42);
    final first = profile.subscribedActresses.single;
    expect(first.actor.displayName, '女优 A');
    expect(first.actor.isSubscribed, isTrue);
    expect(first.matchedMovieCount, 12);
    expect(profile.unsubscribedActresses.single.actor.id, 2);
    expect(profile.tags.single.tagId, 7);
    expect(profile.tags.single.name, '剧情');
    expect(profile.tags.single.matchedMovieCount, 9);
    expect(profile.hasContent, isTrue);
  });

  test('fromJson tolerates missing collections', () {
    final profile = TasteProfileDto.fromJson(<String, dynamic>{
      'sample_movie_count': 1,
    });

    expect(profile.sampleMovieCount, 1);
    expect(profile.subscribedActresses, isEmpty);
    expect(profile.unsubscribedActresses, isEmpty);
    expect(profile.tags, isEmpty);
    expect(profile.hasContent, isFalse);
  });

  test('applySubscription flips the flag without moving the card', () {
    final profile = TasteProfileDto.fromJson(_profileJson());

    final subscribed = profile.applySubscription(
      actorId: 2,
      isSubscribed: true,
    );

    expect(subscribed.unsubscribedActresses.single.actor.id, 2);
    expect(subscribed.unsubscribedActresses.single.actor.isSubscribed, isTrue);
    expect(subscribed.subscribedActresses.single.actor.id, 1);
    expect(subscribed.subscribedActresses.single.actor.isSubscribed, isTrue);

    final unsubscribed = subscribed.applySubscription(
      actorId: 1,
      isSubscribed: false,
    );

    expect(unsubscribed.subscribedActresses.single.actor.id, 1);
    expect(unsubscribed.subscribedActresses.single.actor.isSubscribed, isFalse);
    expect(unsubscribed.unsubscribedActresses.single.actor.id, 2);
  });

  test('subscribing a recommendation-only actress keeps her in place', () {
    final profile = TasteProfileDto.fromJson(<String, dynamic>{
      'sample_movie_count': 42,
      'actresses': <dynamic>[
        _actressJson(id: 1, name: '女优 A', isSubscribed: true),
      ],
      'unsubscribed_actresses': <dynamic>[
        _actressJson(id: 3, name: '女优 C', isSubscribed: false),
      ],
      'tags': <dynamic>[],
    });

    final subscribed = profile.applySubscription(
      actorId: 3,
      isSubscribed: true,
    );

    expect(subscribed.subscribedActresses.single.actor.id, 1);
    expect(subscribed.unsubscribedActresses.single.actor.id, 3);
    expect(subscribed.unsubscribedActresses.single.actor.isSubscribed, isTrue);
  });
}

Map<String, dynamic> _profileJson() {
  return <String, dynamic>{
    'sample_movie_count': 42,
    'actresses': <dynamic>[
      _actressJson(id: 1, name: '女优 A', isSubscribed: true),
      _actressJson(id: 2, name: '女优 B', isSubscribed: false),
    ],
    'unsubscribed_actresses': <dynamic>[
      _actressJson(id: 2, name: '女优 B', isSubscribed: false),
    ],
    'tags': <dynamic>[
      <String, dynamic>{
        'tag_id': 7,
        'name': '剧情',
        'matched_movie_count': 9,
        'score': 21.0,
      },
    ],
  };
}

Map<String, dynamic> _actressJson({
  required int id,
  required String name,
  required bool isSubscribed,
}) {
  return <String, dynamic>{
    'actor': <String, dynamic>{
      'id': id,
      'name': name,
      'alias_name': '',
      'display_name': name,
      'is_subscribed': isSubscribed,
    },
    'matched_movie_count': id == 1 ? 12 : 5,
    'score': id == 1 ? 38.0 : 11.0,
  };
}
