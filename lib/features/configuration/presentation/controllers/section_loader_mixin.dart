import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/widgets/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/feedback/app_section_skeleton.dart';

/// 桌面 configuration 页面的懒加载 section 三态骨架公共 mixin。
///
/// 用于：`if (!widget.active) 不发请求` + `AppSectionSkeleton` 骨架
/// + `AppSectionError` 错误态 + 加载完成后渲染 [buildSectionStates]
/// 的 `buildLoaded` 结果。
///
/// 使用方需要在 [initState] 与 [didUpdateWidget] 显式调 [tryLoadIfActive]
/// （因为 mixin 无法拦截 didUpdateWidget 时判断 widget.active 的变化）。
mixin SectionLoaderMixin<T, W extends StatefulWidget> on State<W> {
  bool _initialized = false;
  bool _isLoading = false;
  String? _errorMessage;

  bool get sectionInitialized => _initialized;
  bool get sectionLoading => _isLoading;
  String? get sectionError => _errorMessage;

  /// 子类通过 widget.xxx 表达当前 tab 是否 active（active 时才发请求）。
  bool get isSectionActive;

  /// 拉取该 section 数据。抛异常会被兜底转成 [_errorMessage]。
  Future<T> fetchSectionData();

  /// 数据到手后写入子类的私有字段（`_applyXxx`）。
  ///
  /// 内部会在 setState block 里调用，勿嵌套 setState。
  void applySectionData(T data);

  /// 加载失败时兜底文案（`apiErrorMessage(error, fallback: ...)`）。
  String get sectionLoadErrorFallback;

  Future<void> loadSectionData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await fetchSectionData();
      if (!mounted) return;
      setState(() {
        applySectionData(data);
        _initialized = true;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initialized = true;
        _isLoading = false;
        _errorMessage = apiErrorMessage(
          error,
          fallback: sectionLoadErrorFallback,
        );
      });
    }
  }

  void tryLoadIfActive() {
    if (isSectionActive && !_initialized && !_isLoading) {
      unawaited(loadSectionData());
    }
  }

  /// 三态渲染：未激活隐藏 → 加载中骨架 → 错误态卡片 → 交给 [buildLoaded]。
  Widget buildSectionStates({
    required String errorTitle,
    required Widget Function(BuildContext context) buildLoaded,
    int skeletonLineCount = 4,
  }) {
    if (!_initialized && !isSectionActive) {
      return const SizedBox.shrink();
    }
    if (_isLoading) {
      return AppSectionSkeleton(lineCount: skeletonLineCount);
    }
    if (_errorMessage != null) {
      return AppSectionError(
        title: errorTitle,
        message: _errorMessage!,
        onRetry: loadSectionData,
      );
    }
    return buildLoaded(context);
  }
}
