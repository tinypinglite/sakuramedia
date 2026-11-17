/// 外部播放器的单媒体传输方式；默认保留后端返回的地址。
enum ExternalPlaybackMode {
  followBackend,
  proxy,
  redirect;

  String applyToUrl(String url) {
    if (this == followBackend) return url;
    final uri = Uri.tryParse(url);
    // 合并播放、切片及非媒体网关地址使用各自的传输契约。
    if (uri == null ||
        !RegExp(r'/media/[0-9]+/play(?:/|$)').hasMatch(uri.path) ||
        !uri.queryParameters.containsKey('signature') ||
        !uri.queryParameters.containsKey('expires')) {
      return url;
    }
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParametersAll,
            'delivery': [name],
          },
        )
        .toString();
  }
}
