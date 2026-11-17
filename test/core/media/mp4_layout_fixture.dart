import 'dart:typed_data';

/// 小体积 MP4 测试夹具：带完整的 moov 采样表，可放在文件头或文件尾。
class Mp4TestFile {
  const Mp4TestFile({
    required this.bytes,
    required this.moovStart,
    required this.moovLength,
  });

  final Uint8List bytes;
  final int moovStart;
  final int moovLength;
}

Mp4TestFile buildMp4TestFile({
  required bool abnormal,
  int mdatBytes = 4 * 1024 * 1024,
  bool fastStart = false,
  int trailingFreeBytes = 0,
}) {
  final moov = buildMoov(
    videoOffsets: <int>[
      for (var index = 0; index < 300; index++)
        abnormal ? index * 10000000 : 100000 + index * 2400,
    ],
    audioOffsets: <int>[
      for (var index = 0; index < 300; index++)
        abnormal ? 5000000000 + index * 10000000 : 100000 + index * 2400 + 1200,
    ],
    useCo64: abnormal,
  );
  final ftyp = _box('ftyp', <int>[...'isom'.codeUnits, 0, 0, 0, 0]);
  final mdat = _box('mdat', List<int>.filled(mdatBytes, 0));
  final builder = BytesBuilder(copy: false);
  final int moovStart;
  if (fastStart) {
    builder.add(ftyp);
    moovStart = ftyp.length;
    builder
      ..add(moov)
      ..add(mdat);
  } else {
    builder
      ..add(ftyp)
      ..add(mdat);
    moovStart = ftyp.length + mdat.length;
    builder.add(moov);
    if (trailingFreeBytes > 0) {
      builder.add(_box('free', List<int>.filled(trailingFreeBytes, 0)));
    }
  }
  return Mp4TestFile(
    bytes: builder.takeBytes(),
    moovStart: moovStart,
    moovLength: moov.length,
  );
}

/// 只带一个 trak/stbl/stsz 的最小 moov，用来喂损坏的 stsz 载荷。
Uint8List buildMoovWithRawStsz(List<int> stszPayload) {
  final stbl = _box('stbl', _fullBox('stsz', 0, 0, stszPayload));
  final mdia = _box('mdia', <int>[
    ..._fullBox('mdhd', 0, 0, <int>[
      ..._u32(0),
      ..._u32(0),
      ..._u32(30),
      ..._u32(0),
      ..._u16(0),
      ..._u16(0),
    ]),
    ..._fullBox('hdlr', 0, 0, <int>[
      ..._u32(0),
      ...'vide'.codeUnits,
      ...List<int>.filled(12, 0),
      0,
    ]),
    ..._box('minf', stbl),
  ]);
  return _box('moov', <int>[..._mvhd(timescale: 1000), ..._box('trak', mdia)]);
}

Uint8List buildMoov({
  required List<int> videoOffsets,
  required List<int> audioOffsets,
  required bool useCo64,
}) {
  final sampleCount = videoOffsets.length;
  return _box('moov', <int>[
    ..._mvhd(timescale: 1000),
    ..._trak(
      handler: 'vide',
      timescale: 30,
      sampleCount: sampleCount,
      sampleSize: 1000,
      offsets: videoOffsets,
      useCo64: useCo64,
    ),
    ..._trak(
      handler: 'soun',
      timescale: 30,
      sampleCount: audioOffsets.length,
      sampleSize: 200,
      offsets: audioOffsets,
      useCo64: useCo64,
    ),
  ]);
}

List<int> _trak({
  required String handler,
  required int timescale,
  required int sampleCount,
  required int sampleSize,
  required List<int> offsets,
  required bool useCo64,
}) {
  final offsetBox = useCo64
      ? _fullBox('co64', 0, 0, <int>[
          ..._u32(offsets.length),
          for (final offset in offsets) ..._u64(offset),
        ])
      : _fullBox('stco', 0, 0, <int>[
          ..._u32(offsets.length),
          for (final offset in offsets) ..._u32(offset),
        ]);
  final stbl = _box('stbl', <int>[
    ..._fullBox('stsz', 0, 0, <int>[..._u32(sampleSize), ..._u32(sampleCount)]),
    ..._fullBox('stts', 0, 0, <int>[
      ..._u32(1),
      ..._u32(sampleCount),
      ..._u32(1),
    ]),
    ..._fullBox('stsc', 0, 0, <int>[
      ..._u32(1),
      ..._u32(1),
      ..._u32(1),
      ..._u32(1),
    ]),
    ...offsetBox,
  ]);
  final mdia = _box('mdia', <int>[
    ..._fullBox('mdhd', 0, 0, <int>[
      ..._u32(0),
      ..._u32(0),
      ..._u32(timescale),
      ..._u32(0),
      ..._u16(0),
      ..._u16(0),
    ]),
    ..._fullBox('hdlr', 0, 0, <int>[
      ..._u32(0),
      ...handler.codeUnits,
      ...List<int>.filled(12, 0),
      0,
    ]),
    ..._box('minf', stbl),
  ]);
  return _box('trak', mdia);
}

List<int> _mvhd({required int timescale}) {
  return _fullBox('mvhd', 0, 0, <int>[
    ..._u32(0),
    ..._u32(0),
    ..._u32(timescale),
    ..._u32(0),
    ..._u32(0x00010000),
    ..._u16(0x0100),
    ...List<int>.filled(10, 0),
    ...List<int>.filled(36, 0),
    ...List<int>.filled(24, 0),
    ..._u32(2),
  ]);
}

Uint8List _box(String type, List<int> payload) {
  return Uint8List.fromList(<int>[
    ..._u32(8 + payload.length),
    ...type.codeUnits,
    ...payload,
  ]);
}

Uint8List _fullBox(String type, int version, int flags, List<int> payload) {
  return _box(type, <int>[
    version & 0xFF,
    (flags >> 16) & 0xFF,
    (flags >> 8) & 0xFF,
    flags & 0xFF,
    ...payload,
  ]);
}

List<int> _u16(int value) => <int>[(value >> 8) & 0xFF, value & 0xFF];

List<int> _u32(int value) => <int>[
  (value >> 24) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
];

List<int> _u64(int value) => <int>[
  (value >> 56) & 0xFF,
  (value >> 48) & 0xFF,
  (value >> 40) & 0xFF,
  (value >> 32) & 0xFF,
  (value >> 24) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
];
