import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';

class Cloud115QrTokenDto {
  const Cloud115QrTokenDto({
    required this.uid,
    required this.time,
    required this.sign,
    required this.qrcodePngBase64,
  });

  final String uid;
  final int time;
  final String sign;
  final String qrcodePngBase64;

  factory Cloud115QrTokenDto.fromJson(Map<String, dynamic> json) {
    return Cloud115QrTokenDto(
      uid: json['uid'] as String? ?? '',
      time: json['time'] as int? ?? 0,
      sign: json['sign'] as String? ?? '',
      qrcodePngBase64: json['qrcode_png_base64'] as String? ?? '',
    );
  }

  Map<String, dynamic> toStatusRequestJson() => <String, dynamic>{
    'uid': uid,
    'time': time,
    'sign': sign,
  };
}

enum Cloud115QrStatus { waiting, scanned, confirmed, expired, canceled }

extension Cloud115QrStatusX on Cloud115QrStatus {
  static Cloud115QrStatus fromWire(dynamic value) => switch (value) {
    'scanned' => Cloud115QrStatus.scanned,
    'confirmed' => Cloud115QrStatus.confirmed,
    'expired' => Cloud115QrStatus.expired,
    'canceled' => Cloud115QrStatus.canceled,
    _ => Cloud115QrStatus.waiting,
  };
}

class Cloud115QrStatusDto {
  const Cloud115QrStatusDto({required this.status});

  final Cloud115QrStatus status;

  factory Cloud115QrStatusDto.fromJson(Map<String, dynamic> json) {
    return Cloud115QrStatusDto(
      status: Cloud115QrStatusX.fromWire(json['status']),
    );
  }
}

class Cloud115LibraryCreatePayload {
  const Cloud115LibraryCreatePayload({
    required this.name,
    required this.uid,
    required this.app,
  });

  final String name;
  final String uid;
  final Cloud115LoginApp app;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'uid': uid,
    'app': app.wireValue,
  };
}

class Cloud115LibraryReauthPayload {
  const Cloud115LibraryReauthPayload({required this.uid, required this.app});

  final String uid;
  final Cloud115LoginApp app;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'uid': uid,
    'app': app.wireValue,
  };
}
