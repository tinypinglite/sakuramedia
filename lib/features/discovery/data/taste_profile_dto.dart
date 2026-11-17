import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';

/// 口味画像里的女优条目：复用女优列表 DTO，并带上命中影片数。
class TasteProfileActressDto {
  const TasteProfileActressDto({
    required this.actor,
    required this.matchedMovieCount,
  });

  final ActorListItemDto actor;
  final int matchedMovieCount;

  TasteProfileActressDto copyWith({ActorListItemDto? actor}) {
    return TasteProfileActressDto(
      actor: actor ?? this.actor,
      matchedMovieCount: matchedMovieCount,
    );
  }

  factory TasteProfileActressDto.fromJson(Map<String, dynamic> json) {
    return TasteProfileActressDto(
      actor: ActorListItemDto.fromJson(asMap(json['actor'])),
      matchedMovieCount: asInt(json['matched_movie_count']),
    );
  }
}

/// 口味画像里的标签条目。`score` 不进入前端 DTO：它不是百分比，
/// 也不适合直接展示给用户。
class TasteProfileTagDto {
  const TasteProfileTagDto({
    required this.tagId,
    required this.name,
    required this.matchedMovieCount,
  });

  final int tagId;
  final String name;
  final int matchedMovieCount;

  factory TasteProfileTagDto.fromJson(Map<String, dynamic> json) {
    return TasteProfileTagDto(
      tagId: asInt(json['tag_id']),
      name: asStringOrNull(json['name'], trim: true) ?? '',
      matchedMovieCount: asInt(json['matched_movie_count']),
    );
  }
}

/// 后端 `GET /taste-profile` 的响应：只保留 UI 需要的字段。
///
/// 分组在解析时冻结：订阅 / 取消只改变卡片的订阅状态，卡片留在原组，
/// 下一次刷新再由服务端重新分组。
class TasteProfileDto {
  const TasteProfileDto({
    required this.sampleMovieCount,
    required this.subscribedActresses,
    required this.unsubscribedActresses,
    required this.tags,
  });

  final int sampleMovieCount;
  final List<TasteProfileActressDto> subscribedActresses;
  final List<TasteProfileActressDto> unsubscribedActresses;
  final List<TasteProfileTagDto> tags;

  bool get hasContent =>
      subscribedActresses.isNotEmpty ||
      unsubscribedActresses.isNotEmpty ||
      tags.isNotEmpty;

  TasteProfileDto applySubscription({
    required int actorId,
    required bool isSubscribed,
  }) {
    return TasteProfileDto(
      sampleMovieCount: sampleMovieCount,
      subscribedActresses: _withSubscription(
        subscribedActresses,
        actorId: actorId,
        isSubscribed: isSubscribed,
      ),
      unsubscribedActresses: _withSubscription(
        unsubscribedActresses,
        actorId: actorId,
        isSubscribed: isSubscribed,
      ),
      tags: tags,
    );
  }

  factory TasteProfileDto.fromJson(Map<String, dynamic> json) {
    final ranked = _actressesFromJson(json['actresses']);
    return TasteProfileDto(
      sampleMovieCount: asInt(json['sample_movie_count']),
      subscribedActresses: List<TasteProfileActressDto>.unmodifiable(
        ranked.where((item) => item.actor.isSubscribed),
      ),
      unsubscribedActresses: _actressesFromJson(json['unsubscribed_actresses']),
      tags: _tagsFromJson(json['tags']),
    );
  }
}

List<TasteProfileActressDto> _withSubscription(
  List<TasteProfileActressDto> items, {
  required int actorId,
  required bool isSubscribed,
}) {
  return List<TasteProfileActressDto>.unmodifiable([
    for (final item in items)
      if (item.actor.id == actorId)
        item.copyWith(actor: item.actor.copyWith(isSubscribed: isSubscribed))
      else
        item,
  ]);
}

List<TasteProfileActressDto> _actressesFromJson(dynamic value) {
  if (value is! List) {
    return const <TasteProfileActressDto>[];
  }
  return List<TasteProfileActressDto>.unmodifiable(
    value.whereType<Map>().map(
      (item) => TasteProfileActressDto.fromJson(asMap(item)),
    ),
  );
}

List<TasteProfileTagDto> _tagsFromJson(dynamic value) {
  if (value is! List) {
    return const <TasteProfileTagDto>[];
  }
  return List<TasteProfileTagDto>.unmodifiable(
    value.whereType<Map>().map(
      (item) => TasteProfileTagDto.fromJson(asMap(item)),
    ),
  );
}
