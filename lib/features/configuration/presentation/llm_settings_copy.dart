class LlmSettingsCopy {
  const LlmSettingsCopy._();

  static const String sharedUsageDescription =
      '当前页面管理 LLM 服务接入参数，现阶段由影片标题翻译和影片简介翻译共用。';
  static const String sharedEndpointDescription =
      '入口名称保持通用 LLM 配置，当前接入的是影片信息翻译共享配置，接口路径仍沿用 `/movie-desc-translation-settings`。';
  static const String baseUrlHelperText = '例如：https://ollama.com';
  static const String modelHintText = '例如：gemma4:31b-cloud';
}
