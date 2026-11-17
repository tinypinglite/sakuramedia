import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/cast/data/cast_director.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';
import 'package:upnp_client/upnp_client.dart';

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

  group('castErrorMessage', () {
    final l10n = AppLocalizationsZh();

    test('优先返回业务错误文案', () {
      expect(
        castErrorMessage(
          const CastException(CastErrorCode.deviceCannotPlayVideo),
          l10n: l10n,
        ),
        '该设备不支持播放视频',
      );
    });

    test('按 UPnP 错误码映射电视拒绝原因', () {
      expect(
        castErrorMessage(UPnPException(errorCode: 704), l10n: l10n),
        '电视不支持播放该视频格式',
      );
      expect(
        castErrorMessage(UPnPException(errorCode: 716), l10n: l10n),
        '电视无法访问该视频地址',
      );
      expect(
        castErrorMessage(UPnPException(errorCode: 999), l10n: l10n),
        '投屏失败，请重试',
      );
    });

    test('网络异常映射为可读提示', () {
      expect(
        castErrorMessage(TimeoutException('timeout'), l10n: l10n),
        '电视未响应，请确认设备处于开机状态',
      );
      expect(
        castErrorMessage(const SocketException('refused'), l10n: l10n),
        '连接电视失败，请确认设备与电视在同一网络',
      );
    });
  });

  test('cast 向电视依次下发 SetAVTransportURI 与 Play', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final soapBodies = <String>[];
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      soapBodies.add(body);
      final action =
          RegExp(r'<u:([A-Za-z]+)').firstMatch(body)?.group(1) ?? '';
      request.response.headers.contentType = ContentType('text', 'xml');
      request.response.write(
        '<?xml version="1.0"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">'
        '<s:Body>'
        '<u:${action}Response '
        'xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"/>'
        '</s:Body>'
        '</s:Envelope>',
      );
      await request.response.close();
    });

    final host = '127.0.0.1:${server.port}';
    final device = buildTestCastDevice(
      address: host,
      renderer: buildTestMediaRenderer(host: host),
    );
    await const CastDirector().cast(
      device: device,
      url: 'http://nas.local/media/1/play/?signature=a&b=c',
      title: '测试影片',
      contentType: 'video/mp4',
    );

    expect(soapBodies, hasLength(2));
    expect(soapBodies[0], contains('<u:SetAVTransportURI'));
    expect(
      soapBodies[0],
      contains('http://nas.local/media/1/play/?signature=a&amp;b=c'),
    );
    expect(soapBodies[0], contains('object.item.videoItem'));
    expect(soapBodies[1], contains('<u:Play'));
  });

  test('cast 在电视返回 SOAP Fault 时抛出 UPnPException', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      await request.drain<void>();
      request.response.statusCode = 500;
      request.response.write(
        '<?xml version="1.0"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">'
        '<s:Body>'
        '<s:Fault><detail>'
        '<UPnPError xmlns="urn:schemas-upnp-org:control-1-0">'
        '<errorCode>716</errorCode>'
        '<errorDescription>Resource not available</errorDescription>'
        '</UPnPError>'
        '</detail></s:Fault>'
        '</s:Body>'
        '</s:Envelope>',
      );
      await request.response.close();
    });

    final host = '127.0.0.1:${server.port}';
    final device = buildTestCastDevice(
      address: host,
      renderer: buildTestMediaRenderer(host: host),
    );
    await expectLater(
      const CastDirector().cast(
        device: device,
        url: 'http://nas.local/media/1/play/?x=1',
        title: '测试影片',
      ),
      throwsA(
        isA<UPnPException>().having((error) => error.errorCode, 'errorCode', 716),
      ),
    );
  });
}
