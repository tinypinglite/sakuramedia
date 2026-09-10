import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';

class ActorDetailDto {
  const ActorDetailDto({
    required this.summary,
    this.gender = 0,
    this.birthday,
    this.age,
    this.heightCm,
    this.bustCm,
    this.waistCm,
    this.hipsCm,
    this.cup,
    this.birthplace,
    this.bloodType,
    this.displayNameOverride,
    this.hasProfileImageOverride = false,
    this.mutationRevision = 0,
  });

  final ActorListItemDto summary;
  final int gender;
  final DateTime? birthday;
  final int? age;
  final int? heightCm;
  final int? bustCm;
  final int? waistCm;
  final int? hipsCm;
  final String? cup;
  final String? birthplace;
  final String? bloodType;
  final String? displayNameOverride;
  final bool hasProfileImageOverride;
  final int mutationRevision;

  factory ActorDetailDto.fromJson(Map<String, dynamic> json) {
    return ActorDetailDto(
      summary: ActorListItemDto.fromJson(json),
      gender: asIntOrNull(json['gender']) ?? 0,
      birthday: asDateTime(json['birthday']),
      age: asIntOrNull(json['age']),
      heightCm: asIntOrNull(json['height_cm']),
      bustCm: asIntOrNull(json['bust_cm']),
      waistCm: asIntOrNull(json['waist_cm']),
      hipsCm: asIntOrNull(json['hips_cm']),
      cup: asStringOrNull(json['cup'], trim: true),
      birthplace: asStringOrNull(json['birthplace'], trim: true),
      bloodType: asStringOrNull(json['blood_type'], trim: true),
      displayNameOverride: asStringOrNull(
        json['display_name_override'],
        trim: true,
      ),
      hasProfileImageOverride:
          json['has_profile_image_override'] as bool? ?? false,
      mutationRevision: asIntOrNull(json['mutation_revision']) ?? 0,
    );
  }
}
