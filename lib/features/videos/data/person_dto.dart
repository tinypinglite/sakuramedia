import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/videos/data/video_item_list_item_dto.dart';

/// 非 JAV 视频域的人物资源（`PersonResource`）。
///
/// 与 JAV 的 `Actor` 不复用：人物只有姓名/头像/性别，关联视频数为 [videoCount]。
class PersonDto {
  const PersonDto({
    required this.id,
    required this.name,
    this.avatarImage,
    this.gender = 0,
    this.videoCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// 与影片 `MovieActorDto.femaleGender` 保持一致的女性性别取值。
  static const int femaleGender = 1;

  final int id;
  final String name;
  final MovieImageDto? avatarImage;
  final int gender;
  final int videoCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isFemale => gender == femaleGender;

  factory PersonDto.fromJson(Map<String, dynamic> json) {
    return PersonDto(
      id: _intFromJson(json['id']) ?? 0,
      name: json['name'] as String? ?? '',
      avatarImage: videoImageFromJson(json['avatar_image']),
      gender: _intFromJson(json['gender']) ?? 0,
      videoCount: _intFromJson(json['video_count']) ?? 0,
      createdAt: videoDateFromJson(json['created_at']),
      updatedAt: videoDateFromJson(json['updated_at']),
    );
  }
}

/// `PATCH /persons/{id}` 的局部更新载荷；字段为 `null` 即不下发、保持原值。
class PersonUpdatePayload {
  const PersonUpdatePayload({this.name, this.gender});

  final String? name;
  final int? gender;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (name != null) 'name': name!.trim(),
      if (gender != null) 'gender': gender,
    };
  }
}

int? _intFromJson(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
