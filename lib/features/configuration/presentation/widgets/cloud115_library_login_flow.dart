import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/cloud115_qr_login_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/media_library_form.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

Future<MediaLibraryBackend?> showMediaLibraryBackendPicker(
  BuildContext context,
) {
  Widget buildBody(BuildContext modalContext) {
    final spacing = modalContext.appSpacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '选择存储类型',
          style: resolveAppTextStyle(
            modalContext,
            size: AppTextSize.s18,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.xs),
        Text(
          '媒体库创建后不能切换存储类型。',
          style: resolveAppTextStyle(
            modalContext,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.lg),
        AppSettingsGroup(
          children: [
            AppSettingCell(
              key: const Key('media-library-backend-local'),
              icon: Icons.folder_open_outlined,
              title: '本地存储',
              subtitle: '使用后端服务器可访问的本地目录',
              trailing: const AppSettingCellChevron(),
              onTap: () => Navigator.of(
                modalContext,
              ).pop(MediaLibraryBackend.local),
            ),
            AppSettingCell(
              key: const Key('media-library-backend-cloud115'),
              icon: Icons.cloud_outlined,
              title: '115 网盘',
              subtitle: '扫码登录并使用 115 网盘存储媒体',
              trailing: const AppSettingCellChevron(),
              onTap: () => Navigator.of(
                modalContext,
              ).pop(MediaLibraryBackend.cloud115),
            ),
          ],
        ),
      ],
    );
  }

  final platform = Provider.of<AppPlatform?>(context, listen: false);
  if (platform == AppPlatform.mobile) {
    return showAppBottomDrawer<MediaLibraryBackend>(
      context: context,
      drawerKey: const Key('media-library-backend-picker-drawer'),
      maxHeightFactor: 0.48,
      builder: buildBody,
    );
  }
  return showDialog<MediaLibraryBackend>(
    context: context,
    builder: (dialogContext) => AppDesktopDialog(
      dialogKey: const Key('media-library-backend-picker-dialog'),
      width: dialogContext.appLayoutTokens.dialogWidthMd,
      child: buildBody(dialogContext),
    ),
  );
}

Future<MediaLibraryDto?> showCloud115LibraryLoginFlow(
  BuildContext context, {
  MediaLibraryDto? reauthLibrary,
}) {
  Widget buildBody(BuildContext modalContext) => _Cloud115LibraryLoginBody(
        reauthLibrary: reauthLibrary,
      );

  final platform = Provider.of<AppPlatform?>(context, listen: false);
  if (platform == AppPlatform.mobile) {
    return showAppBottomDrawer<MediaLibraryDto>(
      context: context,
      drawerKey: const Key('cloud115-login-drawer'),
      heightFactor: 0.9,
      enableDrag: false,
      isDismissible: false,
      builder: buildBody,
    );
  }
  return showDialog<MediaLibraryDto>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AppDesktopDialog(
      dialogKey: const Key('cloud115-login-dialog'),
      width: dialogContext.appLayoutTokens.dialogWidthMd,
      showCloseButton: false,
      child: buildBody(dialogContext),
    ),
  );
}

const List<Cloud115LoginApp> _visibleCloud115LoginApps = <Cloud115LoginApp>[
  Cloud115LoginApp.alipaymini,
  Cloud115LoginApp.wechatmini,
];

enum _Cloud115FlowStep { configuration, qr }

enum _Cloud115QrPhase {
  loading,
  waiting,
  scanned,
  expired,
  canceled,
  pollError,
  submitting,
  submitError,
}

class _Cloud115LibraryLoginBody extends StatefulWidget {
  const _Cloud115LibraryLoginBody({this.reauthLibrary});

  final MediaLibraryDto? reauthLibrary;

  @override
  State<_Cloud115LibraryLoginBody> createState() =>
      _Cloud115LibraryLoginBodyState();
}

class _Cloud115LibraryLoginBodyState extends State<_Cloud115LibraryLoginBody> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  _Cloud115FlowStep _step = _Cloud115FlowStep.configuration;
  late Cloud115LoginApp _selectedApp;
  late Cloud115LoginApp _lockedApp;
  String _lockedName = '';
  bool _riskAccepted = false;
  bool _showRiskError = false;

  _Cloud115QrPhase _phase = _Cloud115QrPhase.loading;
  Cloud115QrTokenDto? _token;
  Uint8List? _qrImageBytes;
  String? _errorMessage;
  int _generation = 0;

  bool get _isReauth => widget.reauthLibrary != null;
  bool get _isSubmitting => _phase == _Cloud115QrPhase.submitting;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _selectedApp = _isReauth
        ? widget.reauthLibrary!.cloud115App
        : Cloud115LoginApp.alipaymini;
    _lockedApp = _selectedApp;
  }

  @override
  void dispose() {
    _generation += 1;
    _nameController.dispose();
    super.dispose();
  }

  void _close() {
    if (_isSubmitting) {
      return;
    }
    _generation += 1;
    Navigator.of(context).pop();
  }

  Future<void> _continueToQr() async {
    FocusScope.of(context).unfocus();
    final valid = _isReauth || (_formKey.currentState?.validate() ?? false);
    if (!valid || !_riskAccepted) {
      setState(() => _showRiskError = !_riskAccepted);
      return;
    }
    _lockedName = _nameController.text.trim();
    _lockedApp = _selectedApp;
    setState(() => _step = _Cloud115FlowStep.qr);
    await _loadQrToken();
  }

  Future<void> _loadQrToken() async {
    final generation = ++_generation;
    setState(() {
      _phase = _Cloud115QrPhase.loading;
      _token = null;
      _qrImageBytes = null;
      _errorMessage = null;
    });
    try {
      final token =
          await context.read<MediaLibrariesApi>().getCloud115QrToken();
      final bytes = base64Decode(token.qrcodePngBase64);
      if (!_isCurrent(generation)) {
        return;
      }
      setState(() {
        _token = token;
        _qrImageBytes = bytes;
        _phase = _Cloud115QrPhase.waiting;
      });
      unawaited(_pollStatus(generation, token));
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }
      setState(() {
        _phase = _Cloud115QrPhase.pollError;
        _errorMessage = apiErrorMessage(error, fallback: '二维码加载失败，请重试。');
      });
    }
  }

  Future<void> _pollStatus(
    int generation,
    Cloud115QrTokenDto token,
  ) async {
    final api = context.read<MediaLibrariesApi>();
    while (_isCurrent(generation)) {
      Cloud115QrStatusDto result;
      try {
        result = await api.pollCloud115QrStatus(token);
      } catch (error) {
        if (!_isCurrent(generation)) {
          return;
        }
        setState(() {
          _phase = _Cloud115QrPhase.pollError;
          _errorMessage = apiErrorMessage(error, fallback: '扫码状态检测失败，请重试。');
        });
        return;
      }
      if (!_isCurrent(generation)) {
        return;
      }
      switch (result.status) {
        case Cloud115QrStatus.waiting:
          setState(() => _phase = _Cloud115QrPhase.waiting);
        case Cloud115QrStatus.scanned:
          setState(() => _phase = _Cloud115QrPhase.scanned);
        case Cloud115QrStatus.confirmed:
          await _submit(generation, token);
          return;
        case Cloud115QrStatus.expired:
          setState(() => _phase = _Cloud115QrPhase.expired);
          return;
        case Cloud115QrStatus.canceled:
          setState(() => _phase = _Cloud115QrPhase.canceled);
          return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _retryPoll() async {
    final token = _token;
    if (token == null) {
      await _loadQrToken();
      return;
    }
    final generation = ++_generation;
    setState(() {
      _phase = _Cloud115QrPhase.waiting;
      _errorMessage = null;
    });
    await _pollStatus(generation, token);
  }

  Future<void> _submit(int generation, Cloud115QrTokenDto token) async {
    if (!_isCurrent(generation) || _isSubmitting) {
      return;
    }
    setState(() {
      _phase = _Cloud115QrPhase.submitting;
      _errorMessage = null;
    });
    try {
      final api = context.read<MediaLibrariesApi>();
      final MediaLibraryDto library;
      if (_isReauth) {
        library = await api.reauthCloud115Library(
          libraryId: widget.reauthLibrary!.id,
          payload: Cloud115LibraryReauthPayload(
            uid: token.uid,
            app: _lockedApp,
          ),
        );
      } else {
        library = await api.createCloud115Library(
          Cloud115LibraryCreatePayload(
            name: _lockedName,
            uid: token.uid,
            app: _lockedApp,
          ),
        );
      }
      if (!mounted) {
        return;
      }
      if (!_isCurrent(generation)) {
        return;
      }
      Navigator.of(context).pop(library);
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }
      setState(() {
        _phase = _Cloud115QrPhase.submitError;
        _errorMessage = apiErrorMessage(
          error,
          fallback: _isReauth ? '115 媒体库重新认证失败。' : '115 媒体库创建失败。',
        );
      });
    }
  }

  Future<void> _retrySubmit() async {
    final token = _token;
    if (token == null) {
      await _loadQrToken();
      return;
    }
    final generation = ++_generation;
    await _submit(generation, token);
  }

  void _backToConfiguration() {
    if (_isSubmitting) {
      return;
    }
    _generation += 1;
    setState(() {
      _step = _Cloud115FlowStep.configuration;
      _token = null;
      _qrImageBytes = null;
      _errorMessage = null;
      _phase = _Cloud115QrPhase.loading;
      _riskAccepted = false;
      _showRiskError = false;
    });
  }

  bool _isCurrent(int generation) => mounted && generation == _generation;

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: !_isSubmitting,
      child: SingleChildScrollView(
        child: _step == _Cloud115FlowStep.configuration
            ? _buildConfiguration(context)
            : _buildQr(context),
      ),
    );
  }

  Widget _buildConfiguration(BuildContext context) {
    final spacing = context.appSpacing;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(
            context,
            title: _isReauth ? '重新认证 115 媒体库' : '添加 115 网盘',
          ),
          SizedBox(height: spacing.xs),
          Text(
            _isReauth
                ? '重新扫码将更新“${widget.reauthLibrary!.name}”的登录凭据。'
                : '选择专门留给 SakuraMedia 使用的 115 登录平台。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.lg),
          if (!_isReauth) ...[
            AppTextField(
              fieldKey: const Key('cloud115-library-name-field'),
              controller: _nameController,
              label: '媒体库名称',
              hintText: '例如：115 主账号',
              validator: validateMediaLibraryName,
              textInputAction: TextInputAction.next,
            ),
            SizedBox(height: spacing.md),
          ],
          AppSelectField<Cloud115LoginApp>(
            key: const Key('cloud115-login-app-field'),
            label: '登录平台',
            value: _selectedApp,
            items: _visibleCloud115LoginApps
                .map(
                  (app) => DropdownMenuItem<Cloud115LoginApp>(
                    value: app,
                    child: Text(
                      app.isRecommended ? '${app.label}（推荐）' : app.label,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null || value == _selectedApp) {
                return;
              }
              setState(() {
                _selectedApp = value;
                _riskAccepted = false;
                _showRiskError = false;
              });
            },
          ),
          SizedBox(height: spacing.md),
          AppNoticeCard(
            leadingIcon: Icons.warning_amber_rounded,
            title: '登录平台将被占用',
            description:
                'SakuraMedia 将持续占用“${_selectedApp.label}”登录槽。请勿再在该平台手动登录，否则可能导致媒体库认证失效；其他登录平台不受影响。',
          ),
          SizedBox(height: spacing.sm),
          CheckboxListTile(
            key: const Key('cloud115-login-risk-checkbox'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _riskAccepted,
            onChanged: (value) {
              setState(() {
                _riskAccepted = value ?? false;
                _showRiskError = false;
              });
            },
            title: Text(
              '我已了解 SakuraMedia 将占用“${_selectedApp.label}”登录槽，并且不会再在该平台手动登录。',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.primary,
              ),
            ),
          ),
          if (_showRiskError)
            Text(
              '请先确认登录平台占用风险',
              key: const Key('cloud115-login-risk-error'),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.error,
              ),
            ),
          SizedBox(height: spacing.lg),
          Row(
            children: [
              Expanded(child: AppButton(label: '取消', onPressed: _close)),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppButton(
                  key: const Key('cloud115-login-continue-button'),
                  label: '继续扫码',
                  variant: AppButtonVariant.primary,
                  onPressed: _continueToQr,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQr(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          context,
          title: _isReauth ? '扫码重新认证' : '扫码登录 115',
        ),
        SizedBox(height: spacing.xs),
        Text(
          '正在登录到：${_lockedApp.label}',
          key: const Key('cloud115-login-target-app'),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.medium,
            tone: AppTextTone.accent,
          ),
        ),
        SizedBox(height: spacing.lg),
        Center(child: _buildQrImage(context)),
        SizedBox(height: spacing.lg),
        Text(
          _statusMessage,
          key: const Key('cloud115-login-status'),
          textAlign: TextAlign.center,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.medium,
            tone:
                _errorMessage == null ? AppTextTone.primary : AppTextTone.error,
          ),
        ),
        if (_errorMessage != null) ...[
          SizedBox(height: spacing.xs),
          Text(
            _errorMessage!,
            key: const Key('cloud115-login-error'),
            textAlign: TextAlign.center,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.error,
            ),
          ),
        ],
        SizedBox(height: spacing.lg),
        Row(
          children: [
            Expanded(
              child: AppButton(
                key: const Key('cloud115-login-back-button'),
                label: '返回修改',
                onPressed: _isSubmitting ? null : _backToConfiguration,
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(child: _buildQrActionButton()),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, {required String title}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s18,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
        ),
        AppIconButton(
          key: const Key('cloud115-login-close-button'),
          tooltip: '关闭',
          onPressed: _isSubmitting ? null : _close,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }

  Widget _buildQrImage(BuildContext context) {
    final colors = context.appColors;
    final image = _qrImageBytes;
    return Container(
      key: const Key('cloud115-login-qr-container'),
      width: 224,
      height: 224,
      alignment: Alignment.center,
      padding: EdgeInsets.all(context.appSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: image == null
          ? const CircularProgressIndicator()
          : Image.memory(
              image,
              key: const Key('cloud115-login-qr-image'),
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
    );
  }

  Widget _buildQrActionButton() {
    return switch (_phase) {
      _Cloud115QrPhase.loading => AppButton(
          key: const Key('cloud115-login-primary-button'),
          label: '加载二维码',
          isLoading: true,
          onPressed: null,
        ),
      _Cloud115QrPhase.waiting || _Cloud115QrPhase.scanned => AppButton(
          key: const Key('cloud115-login-primary-button'),
          label: '等待确认',
          variant: AppButtonVariant.primary,
          onPressed: null,
        ),
      _Cloud115QrPhase.expired || _Cloud115QrPhase.canceled => AppButton(
          key: const Key('cloud115-login-primary-button'),
          label: '刷新二维码',
          variant: AppButtonVariant.primary,
          onPressed: _loadQrToken,
        ),
      _Cloud115QrPhase.pollError => AppButton(
          key: const Key('cloud115-login-primary-button'),
          label: _token == null ? '重新加载二维码' : '重试检测',
          variant: AppButtonVariant.primary,
          onPressed: _token == null ? _loadQrToken : _retryPoll,
        ),
      _Cloud115QrPhase.submitting => AppButton(
          key: const Key('cloud115-login-primary-button'),
          label: _isReauth ? '正在更新认证' : '正在创建媒体库',
          variant: AppButtonVariant.primary,
          isLoading: true,
          onPressed: null,
        ),
      _Cloud115QrPhase.submitError => AppButton(
          key: const Key('cloud115-login-primary-button'),
          label: _isReauth ? '重试认证' : '重试创建',
          variant: AppButtonVariant.primary,
          onPressed: _retrySubmit,
        ),
    };
  }

  String get _statusMessage => switch (_phase) {
        _Cloud115QrPhase.loading => '正在加载二维码…',
        _Cloud115QrPhase.waiting => '请使用 115 App 扫码',
        _Cloud115QrPhase.scanned => '已扫码，请在手机上确认',
        _Cloud115QrPhase.expired => '二维码已过期',
        _Cloud115QrPhase.canceled => '本次扫码已取消',
        _Cloud115QrPhase.pollError => _token == null ? '二维码加载失败' : '扫码状态检测失败',
        _Cloud115QrPhase.submitting =>
          _isReauth ? '扫码已确认，正在更新认证…' : '扫码已确认，正在创建媒体库…',
        _Cloud115QrPhase.submitError => _isReauth ? '重新认证失败' : '媒体库创建失败',
      };
}
