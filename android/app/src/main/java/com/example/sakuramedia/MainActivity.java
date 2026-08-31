package com.example.sakuramedia;

import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.net.Uri;
import android.text.TextUtils;

import androidx.annotation.NonNull;

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
    private static final String VIDEO_MIME = "video/*";
    private static final String FALLBACK_SAMPLE_URL = "http://127.0.0.1/video.mp4";
    // 外部播放器通用 intent extra：position 单位毫秒、title 为媒体标题。
    private static final String EXTRA_POSITION = "position";
    private static final String EXTRA_TITLE = "title";
    // MX Player 系列读 int 型 position，其余（VLC 等）读 long 型。
    private static final String MX_PLAYER_PACKAGE_PREFIX = "com.mxtech";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(this::handleMethodCall);
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
            player.put("packageName", packageName);
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
        final String packageName = call.argument("packageName");
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
}
