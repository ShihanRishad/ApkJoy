package com.shihanrishad.apkjoy

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "apkjoy"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "extractApk") {
                    // This will extract the apk on the call from /lib/main.dart
                    val packageName = call.argument<String>("packageName")
                    val destination = call.argument<String>("destination")
                    if (packageName == null || destination == null) {
                        result.error("INVALID", "Missing packageName or destination", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val packageManager = applicationContext.packageManager
                        val appInfo = packageManager.getApplicationInfo(packageName, 0)
                        val sourcePath = appInfo.sourceDir

                        val destFile = File(destination)
                        destFile.parentFile?.mkdirs()

                        // Copy the APK from its source to the destination
                        FileInputStream(File(sourcePath)).use { input ->
                            FileOutputStream(destFile).use { output ->
                                val buffer = ByteArray(1024)
                                var bytesRead: Int
                                while (input.read(buffer).also { bytesRead = it } != -1) {
                                    output.write(buffer, 0, bytesRead)
                                }
                                output.flush()
                            }
                        }
                        result.success(destination)
                    } catch (e: Exception) {
                        result.error("ERROR", e.localizedMessage, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}