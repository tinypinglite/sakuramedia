import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('sakuramedia/external_player');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('iOS 平台 isSupported 为 false 且方法安全降级', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    const external = ExternalPlayerChannel();

    expect(external.isSupported, isFalse);
    expect(await external.listPlayers(), isEmpty);
    expect(
      await external.launch(playerId: 'org.videolan.vlc', url: 'http://x/v'),
      isFalse,
    );
  });

  test('macOS 与 Windows 支持外部播放器通道', () {
    for (final platform in <TargetPlatform>[
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(const ExternalPlayerChannel().isSupported, isTrue);
    }
  });

  test('listPlayers 解析原生返回并按名称排序', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'listPlayers');
      expect((call.arguments as Map)['sampleUrl'], 'http://nas:8000');
      return <Map<String, String>>[
        <String, String>{'id': 'org.videolan.vlc', 'label': 'VLC'},
        <String, String>{
          'id': 'com.mxtech.videoplayer.ad',
          'label': 'MX Player',
        },
      ];
    });

    const external = ExternalPlayerChannel();
    final players = await external.listPlayers(sampleUrl: 'http://nas:8000');

    expect(players.map((p) => p.label).toList(), <String>['MX Player', 'VLC']);
    expect(players.first.id, 'com.mxtech.videoplayer.ad');
  });

  test('listPlayers 丢弃缺少标识的无效条目', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return <dynamic>[
        <String, String>{'label': '缺标识'},
        <String, String>{'id': 'org.videolan.vlc', 'label': 'VLC'},
      ];
    });

    const external = ExternalPlayerChannel();
    final players = await external.listPlayers();

    expect(players, hasLength(1));
    expect(players.single.id, 'org.videolan.vlc');
  });

  test('launch 透传播放器标识/直链/标题/位置参数', () async {
    MethodCall? captured;
    messenger.setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return true;
    });

    const external = ExternalPlayerChannel();
    final launched = await external.launch(
      playerId: 'org.videolan.vlc',
      url: 'http://nas:8000/media/1/play/?expires=1777777777&signature=abc',
      title: '影片标题',
      positionMs: 90000,
    );

    expect(launched, isTrue);
    expect(captured?.method, 'launch');
    final args = captured!.arguments as Map;
    expect(args['playerId'], 'org.videolan.vlc');
    expect(
      args['url'],
      'http://nas:8000/media/1/play/?expires=1777777777&signature=abc',
    );
    expect(args['title'], '影片标题');
    expect(args['positionMs'], 90000);
  });

  test('原生抛出异常时 launch 返回 false', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'launch_failed');
    });

    const external = ExternalPlayerChannel();
    expect(
      await external.launch(playerId: 'org.videolan.vlc', url: 'http://x/v'),
      isFalse,
    );
  });
}
