import 'package:sakuramedia/features/cast/data/cast_device.dart';
import 'package:sakuramedia/features/cast/data/cast_session.dart';
import 'package:sakuramedia/features/cast/data/cast_transport.dart';
import 'package:upnp_client/upnp_client.dart';
import 'package:xml/xml.dart';

/// 构造测试用 DLNA 媒体渲染器；[host] 为设备描述与 SOAP 端点所在主机。
MediaRenderer buildTestMediaRenderer({
  String friendlyName = '测试电视',
  String udn = 'uuid:test-tv-0001',
  String host = '127.0.0.1:9000',
}) {
  final description =
      '''
<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
    <friendlyName>$friendlyName</friendlyName>
    <UDN>$udn</UDN>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:AVTransport</serviceId>
        <SCPDURL>/AVTransport/scpd.xml</SCPDURL>
        <controlURL>/AVTransport/control</controlURL>
        <eventSubURL>/AVTransport/event</eventSubURL>
      </service>
    </serviceList>
  </device>
</root>
''';
  final deviceXml = XmlDocument.parse(
    description,
  ).rootElement.getElement('device')!;
  final location = 'http://$host/description.xml';
  return Device.fromXmlTyped(deviceXml, location, 'http://$host/')
      as MediaRenderer;
}

/// 构造测试用投屏设备。
CastDevice buildTestCastDevice({
  String id = 'uuid:test-tv-0001',
  String name = '测试电视',
  String address = '127.0.0.1:9000',
  MediaRenderer? renderer,
}) {
  return CastDevice(
    id: id,
    name: name,
    address: address,
    renderer: renderer ?? buildTestMediaRenderer(host: address),
  );
}

/// 构造测试用投屏会话。
CastSession buildTestCastSession({
  int mediaId = 7,
  String movieNumber = 'ABC-001',
  int durationSeconds = 3600,
  MediaRenderer? renderer,
}) {
  return CastSession(
    device: buildTestCastDevice(renderer: renderer),
    mediaId: mediaId,
    movieNumber: movieNumber,
    durationSeconds: durationSeconds,
  );
}

/// 可编程的传输层假实现，供控制器与遥控页测试共用。
class FakeCastTransport implements CastTransport {
  CastPositionInfo position = const CastPositionInfo(position: Duration.zero);
  CastPlaybackStatus status = CastPlaybackStatus.playing;
  Object? failure;
  final List<Duration> seeks = <Duration>[];
  final List<String> calls = <String>[];

  void _maybeThrow() {
    final error = failure;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<CastPositionInfo> positionInfo() async {
    calls.add('position');
    _maybeThrow();
    return position;
  }

  @override
  Future<CastPlaybackStatus> playbackStatus() async {
    calls.add('status');
    _maybeThrow();
    return status;
  }

  @override
  Future<void> seek(Duration target) async {
    calls.add('seek');
    _maybeThrow();
    seeks.add(target);
  }

  @override
  Future<void> play() async {
    calls.add('play');
    _maybeThrow();
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _maybeThrow();
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    _maybeThrow();
  }
}
