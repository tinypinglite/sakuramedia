import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/cast/data/cast_device.dart';
import 'package:sakuramedia/features/cast/data/cast_transport.dart';

import '../../support/cast_test_helpers.dart';

void main() {
  // TestWidgetsFlutterBinding 会把所有 HttpClient 请求 mock 成 HTTP 400；
  // 这里的 SOAP 往返走真实 loopback，需要临时关闭该 mock，结束再放回。
  HttpOverrides? savedHttpOverrides;

  setUp(() {
    savedHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
  });

  tearDown(() {
    HttpOverrides.global = savedHttpOverrides;
  });

  group('parseUpnpTime', () {
    test('解析标准 HH:MM:SS 与小数秒', () {
      expect(
        parseUpnpTime('00:12:34'),
        const Duration(minutes: 12, seconds: 34),
      );
      expect(
        parseUpnpTime('01:02:03.500'),
        const Duration(
          hours: 1,
          minutes: 2,
          seconds: 3,
          milliseconds: 500,
        ),
      );
      expect(parseUpnpTime('00:00:00'), Duration.zero);
    });

    test('无效值返回 null', () {
      expect(parseUpnpTime(null), isNull);
      expect(parseUpnpTime(''), isNull);
      expect(parseUpnpTime('NOT_IMPLEMENTED'), isNull);
      expect(parseUpnpTime('12:34'), isNull);
    });
  });

  group('formatUpnpTime', () {
    test('输出 HH:MM:SS', () {
      expect(formatUpnpTime(Duration.zero), '00:00:00');
      expect(
        formatUpnpTime(const Duration(hours: 1, minutes: 1, seconds: 1)),
        '01:01:01',
      );
      expect(formatUpnpTime(const Duration(hours: 25)), '25:00:00');
    });

    test('负值按 0 处理', () {
      expect(formatUpnpTime(const Duration(seconds: -5)), '00:00:00');
    });
  });

  test('positionInfo 解析位置与时长，容错 NOT_IMPLEMENTED', () async {
    final server = await _startMockRenderer((action, _) {
      if (action == 'GetPositionInfo') {
        return _soapResponse(
          action,
          '<Track>1</Track>'
          '<TrackDuration>01:58:00</TrackDuration>'
          '<RelTime>00:42:10.000</RelTime>',
        );
      }
      return null;
    });
    addTearDown(() => server.close(force: true));
    final transport = UpnpCastTransport(_deviceFor(server));

    final info = await transport.positionInfo();
    expect(info.position, const Duration(minutes: 42, seconds: 10));
    expect(info.duration, const Duration(hours: 1, minutes: 58));

    final tolerantServer = await _startMockRenderer((action, _) {
      if (action == 'GetPositionInfo') {
        return _soapResponse(
          action,
          '<TrackDuration>NOT_IMPLEMENTED</TrackDuration>'
          '<RelTime>NOT_IMPLEMENTED</RelTime>',
        );
      }
      return null;
    });
    addTearDown(() => tolerantServer.close(force: true));
    final tolerantInfo = await UpnpCastTransport(
      _deviceFor(tolerantServer),
    ).positionInfo();
    expect(tolerantInfo.position, Duration.zero);
    expect(tolerantInfo.duration, isNull);
  });

  test('playbackStatus 映射 DLNA 传输状态', () async {
    final states = <String, CastPlaybackStatus>{
      'PLAYING': CastPlaybackStatus.playing,
      'PAUSED_PLAYBACK': CastPlaybackStatus.paused,
      'STOPPED': CastPlaybackStatus.stopped,
      'TRANSITIONING': CastPlaybackStatus.transitioning,
    };
    for (final entry in states.entries) {
      final server = await _startMockRenderer((action, _) {
        if (action == 'GetTransportInfo') {
          return _soapResponse(
            action,
            '<CurrentTransportState>${entry.key}'
            '</CurrentTransportState>'
            '<CurrentTransportStatus>OK</CurrentTransportStatus>'
            '<CurrentSpeed>1</CurrentSpeed>',
          );
        }
        return null;
      });
      final transport = UpnpCastTransport(_deviceFor(server));
      expect(await transport.playbackStatus(), entry.value);
      await server.close(force: true);
    }
  });

  test('seek 发送 REL_TIME 目标，play/pause/stop 下发对应动作', () async {
    final actions = <String>[];
    final bodies = <String>[];
    final server = await _startMockRenderer((action, body) {
      actions.add(action);
      bodies.add(body);
      return null;
    });
    addTearDown(() => server.close(force: true));
    final transport = UpnpCastTransport(_deviceFor(server));

    await transport.seek(const Duration(minutes: 3, seconds: 7));
    await transport.play();
    await transport.pause();
    await transport.stop();

    expect(actions, ['Seek', 'Play', 'Pause', 'Stop']);
    expect(bodies[0], contains('<Unit>REL_TIME</Unit>'));
    expect(bodies[0], contains('<Target>00:03:07</Target>'));
  });

  test('设备不响应时按传入超时抛出 TimeoutException', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      // 故意不响应、不关闭连接，模拟电视离线。
    });
    final transport = UpnpCastTransport(
      _deviceFor(server),
      actionTimeout: const Duration(milliseconds: 300),
    );

    await expectLater(
      transport.positionInfo(),
      throwsA(isA<TimeoutException>()),
    );
  });
}

Future<HttpServer> _startMockRenderer(
  String? Function(String action, String body) responder,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final body = await utf8.decoder.bind(request).join();
    final action =
        RegExp(r'<u:([A-Za-z]+)').firstMatch(body)?.group(1) ?? '';
    request.response.headers.contentType = ContentType('text', 'xml');
    request.response.write(responder(action, body) ?? _soapResponse(action, ''));
    await request.response.close();
  });
  return server;
}

String _soapResponse(String action, String outArgs) =>
    '<?xml version="1.0"?>'
    '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">'
    '<s:Body>'
    '<u:${action}Response '
    'xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">'
    '$outArgs'
    '</u:${action}Response>'
    '</s:Body>'
    '</s:Envelope>';

CastDevice _deviceFor(HttpServer server) {
  final host = '127.0.0.1:${server.port}';
  return buildTestCastDevice(
    address: host,
    renderer: buildTestMediaRenderer(host: host),
  );
}
