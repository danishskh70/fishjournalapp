package com.fishjournal.fish_journal

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channel = "fish_journal/updater"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstall" -> {
                        result.success(
                            Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls()
                        )
                    }

                    "requestInstallPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                        }
                        result.success(true)
                    }

                    "installApk" -> {
                        try {
                            val path = call.argument<String>("path")
                                ?: throw IllegalArgumentException("Missing APK path")
                            val apk = File(path)

                            require(apk.exists() && apk.isFile) {
                                "Downloaded APK not found"
                            }

                            val uri = FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                apk
                            )

                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(
                                    uri,
                                    "application/vnd.android.package-archive"
                                )
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }

                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_FAILED", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
