import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/config/app_image_config.dart';
import 'package:sakuramedia/core/media/app_image_provider.dart';
import 'package:sakuramedia/theme.dart';

/// 开发期图片纯色遮罩。
///
/// `ENABLE_BLUR=true` 时所有图片入口都应在解析 [ImageProvider] 之前短路，
/// 只画一个由图片 URL / 字节内容稳定派生的纯色块。这样既避免意外展示，
/// 也不会产生图片请求、解码或模糊绘制。
abstract final class AppImageMask {
  static bool get enabled => AppImageConfig.enableBlur;

  /// 同一 seed 始终得到同一颜色；空 seed 回退主题占位色。
  static Color colorFor(BuildContext context, String seed) {
    final base = context.appColors.surfaceMuted;
    final normalizedSeed = seed.trim();
    if (normalizedSeed.isEmpty) {
      return base;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hue = (_stableHash(normalizedSeed) % 360).toDouble();
    final tint = HSLColor.fromAHSL(
      1,
      hue,
      0.38,
      isDark ? 0.32 : 0.84,
    ).toColor();
    return Color.alphaBlend(tint.withValues(alpha: isDark ? 0.55 : 0.45), base);
  }

  /// 去掉签名参数后的 URL，保证签名轮换时同一张图颜色不变。
  static String seedForUrl(String rawUrl) {
    final normalizedUrl = rawUrl.trim();
    if (normalizedUrl.isEmpty) {
      return '';
    }
    return stableImageCacheKey(normalizedUrl);
  }

  /// 本地选择/上传图片用内容派生颜色，避免同一文件不同会话颜色漂移。
  static String seedForBytes(Uint8List bytes) {
    var hash = 0x811c9dc5;
    hash = _mix(hash, bytes.length);
    final limit = bytes.length < 64 ? bytes.length : 64;
    for (var index = 0; index < limit; index++) {
      hash = _mix(hash, bytes[index]);
    }
    return 'bytes:$hash';
  }

  static String seedForProvider(ImageProvider<Object>? provider) {
    if (provider is MemoryImage) {
      return seedForBytes(provider.bytes);
    }
    if (provider is FileImage) {
      return provider.file.path;
    }
    if (provider is AssetImage) {
      return provider.assetName;
    }
    if (provider is NetworkImage) {
      return seedForUrl(provider.url);
    }
    if (provider is ResizeImage) {
      return seedForProvider(provider.imageProvider);
    }
    return provider?.toString() ?? '';
  }

  static int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash = _mix(hash, codeUnit);
    }
    return hash;
  }

  static int _mix(int hash, int value) {
    final next = (hash ^ value) * 0x01000193;
    return next & 0xFFFFFFFF;
  }
}
