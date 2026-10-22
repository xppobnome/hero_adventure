package com.xppobnome.hero_adventure

import android.content.Intent
import android.app.PendingIntent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import android.os.Build
import android.net.Uri
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.xppobnome.hero_adventure/native_tools"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openFile" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrEmpty()) {
                            result.error("NO_PATH", "path is null", null)
                        } else {
                            openFile(path, result)
                        }
                    }
                    "createPinnedShortcut" -> {
                        val id = call.argument<String>("id") ?: "child_shortcut"
                        val label = call.argument<String>("label") ?: "英雄闯关"
                        val iconPath = call.argument<String>("iconPath")
                        createPinnedShortcut(id, label, iconPath, result)
                    }
                    "isPinnedShortcutSupported" -> {
                        result.success(isPinnedShortcutSupported())
                    }
                    "openAppSettings" -> {
                        openAppSettings()
                        result.success(true)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrEmpty()) {
                            result.error("NO_PATH", "path is null", null)
                        } else {
                            installApk(path, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** 是否支持请求桌面快捷方式（Android 8.0+ 且系统支持）。 */
    private fun isPinnedShortcutSupported(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val sm = getSystemService(android.content.Context.SHORTCUT_SERVICE)
                    as android.content.pm.ShortcutManager
            sm.isRequestPinShortcutSupported
        } else {
            false
        }
    }

    /** 用系统应用打开本地文件（CSV 等），弹出「选择打开方式」。 */
    private fun openFile(path: String, result: MethodChannel.Result) {
        try {
            val file = File(path)
            if (!file.exists()) {
                result.error("FILE_NOT_FOUND", "文件不存在: $path", null)
                return
            }
            val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    file
                )
            } else {
                Uri.fromFile(file)
            }
            val mime = MimeTypeMap.getSingleton()
                .getMimeTypeFromExtension(file.extension.lowercase())
                ?: "text/csv"
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, "选择打开方式"))
            result.success(true)
        } catch (e: Exception) {
            result.error("OPEN_FAILED", e.message, null)
        }
    }

    /** 打开本应用的系统设置详情页 (用于手动开启「创建桌面快捷方式」权限)。 */
    private fun openAppSettings() {
        try {
            val intent = Intent(
                android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName")
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            // 兜底：打开系统应用设置首页
            try {
                val intent = Intent(android.provider.Settings.ACTION_SETTINGS)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
            } catch (_: Exception) {
            }
        }
    }

    /** 安装本地 APK（自动更新用），通过 FileProvider + ACTION_VIEW 触发系统安装器。
     *  Android 8.0+ 需要用户已在系统设置中为本应用开启「安装未知来源应用」权限。 */
    private fun installApk(path: String, result: MethodChannel.Result) {
        try {
            val file = File(path)
            if (!file.exists()) {
                result.error("APK_NOT_FOUND", "APK 不存在: $path", null)
                return
            }
            val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            } else {
                Uri.fromFile(file)
            }
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("INSTALL_FAILED", e.message, null)
        }
    }

    /** 创建桌面快捷方式（Pinned Shortcut），图标可用任意图片、名字可任意。 */
    private fun createPinnedShortcut(
        id: String,
        label: String,
        iconPath: String?,
        result: MethodChannel.Result
    ) {
        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                // Android 8.0 以下不支持 ShortcutManager，回退到旧式 Intent 快捷方式。
                createLegacyShortcut(id, label, iconPath)
                result.success(true)
                return
            }

            val shortcutManager = getSystemService(android.content.Context.SHORTCUT_SERVICE)
                    as android.content.pm.ShortcutManager

            // 图标：优先用头像文件解码成 Bitmap；失败则用默认启动图标。
            val icon = buildShortcutIcon(iconPath)

            val shortcut = android.content.pm.ShortcutInfo.Builder(this, id)
                .setShortLabel(label)
                .setLongLabel(label)
                .setIcon(icon)
                .setIntent(
                    Intent(Intent.ACTION_MAIN, Uri.EMPTY, this, MainActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                )
                .build()

            // Android 8.0+ 标准做法：用 requestPinShortcut 弹系统确认框。
            // 国内定制 ROM（MIUI/HyperOS、ColorOS、OriginOS 等）会因厂商自定义的
            // 「创建桌面快捷方式」权限被默认拦截，导致 requestPinShortcut 静默返回
            // false 且不弹任何框。此时返回 false，交由 Flutter 端弹「App 内引导 +
            // 跳转系统设置」提示，引导用户手动开启权限后再试。
            val callbackIntent = Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            val callback = PendingIntent.getActivity(
                this,
                0,
                callbackIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            // requestPinShortcut 第二参数为 IntentSender，需从 PendingIntent 取。
            val ok = shortcutManager.requestPinShortcut(shortcut, callback.intentSender)
            result.success(ok)
        } catch (e: Exception) {
            result.error("SHORTCUT_FAILED", e.message, null)
        }
    }

    private fun buildShortcutIcon(iconPath: String?): Icon {
        return try {
            var bmp: Bitmap? = null
            if (!iconPath.isNullOrEmpty()) {
                val f = File(iconPath)
                if (f.exists()) {
                    bmp = BitmapFactory.decodeFile(iconPath)
                }
            }
            if (bmp == null) {
                // 回退：应用默认图标（mipmap）。
                val drawable = applicationInfo.loadIcon(packageManager)
                bmp = Bitmap.createBitmap(
                    drawable.intrinsicWidth.coerceAtLeast(1),
                    drawable.intrinsicHeight.coerceAtLeast(1),
                    Bitmap.Config.ARGB_8888
                )
                val canvas = android.graphics.Canvas(bmp)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
            }
            // 统一缩放为 192x192（launcher 图标标准尺寸）。
            val scaled = Bitmap.createScaledBitmap(bmp, 192, 192, true)
            Icon.createWithBitmap(scaled)
        } catch (e: Exception) {
            // 最终兜底：应用默认图标。
            val drawable = applicationInfo.loadIcon(packageManager)
            val bmp = Bitmap.createBitmap(
                drawable.intrinsicWidth.coerceAtLeast(1),
                drawable.intrinsicHeight.coerceAtLeast(1),
                Bitmap.Config.ARGB_8888
            )
            val canvas = android.graphics.Canvas(bmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            Icon.createWithBitmap(bmp)
        }
    }

    /** 旧式快捷方式（Android < 8.0），通过发送广播添加到桌面。 */
    private fun createLegacyShortcut(id: String, label: String, iconPath: String?) {
        val intent = Intent("com.android.launcher.action.INSTALL_SHORTCUT").apply {
            putExtra(Intent.EXTRA_SHORTCUT_NAME, label)
            putExtra(
                Intent.EXTRA_SHORTCUT_INTENT,
                Intent(Intent.ACTION_MAIN, Uri.EMPTY, this@MainActivity, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            putExtra("duplicate", false)
        }
        var iconBmp: Bitmap? = null
        if (!iconPath.isNullOrEmpty()) {
            val f = File(iconPath)
            if (f.exists()) iconBmp = BitmapFactory.decodeFile(iconPath)
        }
        if (iconBmp == null) {
            val drawable = applicationInfo.loadIcon(packageManager)
            iconBmp = Bitmap.createBitmap(
                drawable.intrinsicWidth.coerceAtLeast(1),
                drawable.intrinsicHeight.coerceAtLeast(1),
                Bitmap.Config.ARGB_8888
            )
            val canvas = android.graphics.Canvas(iconBmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
        }
        intent.putExtra(Intent.EXTRA_SHORTCUT_ICON, iconBmp)
        sendBroadcast(intent)
    }
}
