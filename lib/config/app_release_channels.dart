/// 应用前后端仓库与发布页地址。
///
/// [StatusApi] 用它拼 release API 地址，版本浮层用它打开浏览器；仓库名只在
/// 这里维护一份。
abstract final class AppReleaseChannels {
  static const String frontendRepo = 'tinypinglite/sakuramedia';
  static const String backendRepo = 'tinypinglite/sakuramediabe';

  static const String frontendApiUrl =
      'https://api.github.com/repos/$frontendRepo/releases/latest';
  static const String backendApiUrl =
      'https://api.github.com/repos/$backendRepo/releases/latest';

  static const String frontendPageUrl =
      'https://github.com/$frontendRepo/releases/latest';
  static const String backendPageUrl =
      'https://github.com/$backendRepo/releases/latest';
}
