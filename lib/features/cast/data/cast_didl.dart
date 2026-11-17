/// 生成 DLNA 播放用的视频 DIDL-Lite 元数据。
///
/// upnp_client 自带的 DIDL 构建只覆盖音频场景，投屏需要
/// `object.item.videoItem`，因此按 UPnP 元数据规范拼装最小可用结构。
/// 设备不校验元数据时可以省略，但部分电视会因此拒绝播放。
String buildVideoDidl({
  required String url,
  required String title,
  String? contentType,
}) {
  final resourceType = contentType == null || contentType.isEmpty
      ? 'video/mp4'
      : contentType;
  final displayTitle = title.trim().isEmpty ? url : title.trim();
  return '<DIDL-Lite'
      ' xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"'
      ' xmlns:dc="http://purl.org/dc/elements/1.1/"'
      ' xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
      '<item id="0" parentID="-1" restricted="1">'
      '<dc:title>${_escapeXml(displayTitle)}</dc:title>'
      '<upnp:class>object.item.videoItem</upnp:class>'
      '<res protocolInfo="http-get:*:$resourceType:*">'
      '${_escapeXml(url)}'
      '</res>'
      '</item>'
      '</DIDL-Lite>';
}

String _escapeXml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
