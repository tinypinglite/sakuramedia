package com.example.sakuramedia;

import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.net.Uri;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.text.TextUtils;

import androidx.annotation.NonNull;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "sakuramedia/external_player";
    private static final String MULTICAST_LOCK_CHANNEL = "sakuramedia/multicast_lock";
    private static final String IMMERSIVE_SYSTEM_UI_CHANNEL =
            "sakuramedia/immersive_system_ui";
    private static final String VIDEO_MIME = "video/*";
    private static final String FALLBACK_SAMPLE_URL = "http://127.0.0.1/video.mp4";
    // 外部播放器通用 intent extra：position 单位毫秒、title 为媒体标题。
    private static final String EXTRA_POSITION = "position";
    private static final String EXTRA_TITLE = "title";
    // MX Player 系列读 int 型 position，其余（VLC 等）读 long 型。
    private static final String MX_PLAYER_PACKAGE_PREFIX = "com.mxtech";

    private WifiManager.MulticastLock multicastLock;
    private boolean immersiveSystemUiActive;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(this::handleMethodCall);
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                MULTICAST_LOCK_CHANNEL)
                .setMethodCallHandler(this::handleMulticastLockCall);
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                IMMERSIVE_SYSTEM_UI_CHANNEL)
                .setMethodCallHandler(this::handleImmersiveSystemUiCall);
    }

    private void handleMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "listPlayers":
                result.success(listVideoPlayers(call.argument("sampleUrl")));
                break;
            case "launch":
                handleLaunch(call, result);
                break;
            default:
                result.notImplemented();
        }
    }

    // 枚举系统中能处理“播放视频”的应用。查询用与实际拉起一致的 intent 形态
    // （ACTION_VIEW + 视频 URL + video/* 类型），以保证列出的播放器确实能接住直链。
    private List<Map<String, String>> listVideoPlayers(String sampleUrl) {
        final Uri data = Uri.parse(
                TextUtils.isEmpty(sampleUrl) ? FALLBACK_SAMPLE_URL : sampleUrl);
        final Intent intent = new Intent(Intent.ACTION_VIEW);
        intent.setDataAndType(data, VIDEO_MIME);

        final PackageManager packageManager = getPackageManager();
        final List<ResolveInfo> activities = packageManager.queryIntentActivities(intent, 0);
        final List<Map<String, String>> players = new ArrayList<>();
        final String selfPackage = getPackageName();
        for (final ResolveInfo info : activities) {
            if (info.activityInfo == null) {
                continue;
            }
            final String packageName = info.activityInfo.packageName;
            if (TextUtils.isEmpty(packageName) || packageName.equals(selfPackage)) {
                continue;
            }
            final Map<String, String> player = new HashMap<>();
            player.put("id", packageName);
            player.put("label", String.valueOf(info.loadLabel(packageManager)));
            players.add(player);
        }
        return players;
    }

    private void handleLaunch(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        final String url = call.argument("url");
        if (TextUtils.isEmpty(url)) {
            result.error("invalid_arguments", "缺少播放地址", null);
            return;
        }
        final String packageName = call.argument("playerId");
        final String title = call.argument("title");
        final Number positionMs = call.argument("positionMs");

        final Intent intent = new Intent(Intent.ACTION_VIEW);
        intent.setDataAndType(Uri.parse(url), VIDEO_MIME);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        if (!TextUtils.isEmpty(packageName)) {
            intent.setPackage(packageName);
        }
        if (!TextUtils.isEmpty(title)) {
            intent.putExtra(EXTRA_TITLE, title);
        }
        if (positionMs != null && positionMs.longValue() > 0) {
            // 通用约定：position 单位毫秒。MX Player 读 int，VLC 等读 long。
            if (packageName != null && packageName.startsWith(MX_PLAYER_PACKAGE_PREFIX)) {
                intent.putExtra(EXTRA_POSITION, positionMs.intValue());
            } else {
                intent.putExtra(EXTRA_POSITION, positionMs.longValue());
            }
        }

        try {
            startActivity(intent);
            result.success(true);
        } catch (ActivityNotFoundException error) {
            // 播放器可能已被卸载，交给 Dart 侧提示并回落到应用内播放。
            result.success(false);
        } catch (Exception error) {
            result.error("launch_failed", error.getMessage(), null);
        }
    }

    // 部分设备的 WiFi 芯片默认过滤组播帧，不持有 MulticastLock 时收不到 SSDP
    // 响应；锁在投屏设备搜索期间持有，搜索结束或取消时释放。
    private void handleMulticastLockCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "acquire":
                result.success(acquireMulticastLock());
                break;
            case "release":
                releaseMulticastLock();
                result.success(null);
                break;
            default:
                result.notImplemented();
        }
    }

    private boolean acquireMulticastLock() {
        final WifiManager wifiManager =
                (WifiManager) getApplicationContext().getSystemService(Context.WIFI_SERVICE);
        if (wifiManager == null) {
            return false;
        }
        if (multicastLock == null) {
            multicastLock = wifiManager.createMulticastLock("sakuramedia_cast");
            multicastLock.setReferenceCounted(false);
        }
        if (!multicastLock.isHeld()) {
            try {
                multicastLock.acquire();
            } catch (Exception error) {
                return false;
            }
        }
        return multicastLock.isHeld();
    }

    private void releaseMulticastLock() {
        if (multicastLock == null || !multicastLock.isHeld()) {
            return;
        }
        try {
            multicastLock.release();
        } catch (Exception ignored) {
            // 锁可能已被系统回收，无需处理。
        }
    }

    private void handleImmersiveSystemUiCall(
            @NonNull MethodCall call,
            @NonNull MethodChannel.Result result) {
        if (!"setImmersive".equals(call.method)) {
            result.notImplemented();
            return;
        }
        final Boolean enabled = call.argument("enabled");
        if (enabled == null) {
            result.error("invalid_arguments", "缺少 enabled 参数", null);
            return;
        }
        setImmersiveSystemUi(enabled);
        result.success(null);
    }

    private void setImmersiveSystemUi(boolean enabled) {
        immersiveSystemUiActive = enabled;
        // targetSdk 36 在 Android 15+ 强制 edge-to-edge；旧系统仍需在播放/看图时
        // 临时关闭 decorFits，避免系统栏瞬时呼出时画面被挤动。
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            WindowCompat.setDecorFitsSystemWindows(getWindow(), !enabled);
        }
        final WindowInsetsControllerCompat controller = windowInsetsController();
        if (enabled) {
            controller.setSystemBarsBehavior(
                    WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
            controller.hide(WindowInsetsCompat.Type.systemBars());
            return;
        }
        controller.setSystemBarsBehavior(WindowInsetsControllerCompat.BEHAVIOR_DEFAULT);
        controller.show(WindowInsetsCompat.Type.systemBars());
    }

    private WindowInsetsControllerCompat windowInsetsController() {
        return WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
    }

    private void hideSystemBarsIfImmersive() {
        if (!immersiveSystemUiActive) {
            return;
        }
        final WindowInsetsControllerCompat controller = windowInsetsController();
        controller.setSystemBarsBehavior(
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
        controller.hide(WindowInsetsCompat.Type.systemBars());
    }

    @Override
    public void onPostResume() {
        super.onPostResume();
        hideSystemBarsIfImmersive();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            hideSystemBarsIfImmersive();
        }
    }

    @Override
    protected void onDestroy() {
        // 兜底：Dart 侧未正常释放时（异常退出搜索等）避免锁泄漏到进程结束。
        releaseMulticastLock();
        super.onDestroy();
    }
}
