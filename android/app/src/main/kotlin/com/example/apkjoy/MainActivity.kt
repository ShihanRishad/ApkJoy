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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "extractApk") {
                val packageName = call.argument<String>("packageName")
                if (packageName == null) {
                    result.error("ERROR", "Package name is null", null)
                    return@setMethodCallHandler
                }
                try {
                    val packageManager = applicationContext.packageManager
                    val appInfo = packageManager.getApplicationInfo(packageName, 0)
                    val sourcePath = appInfo.sourceDir
                    val outputDir = File(applicationContext.getExternalFilesDir(null), "ExtractedAPKs")
                    if (!outputDir.exists()) {
                        outputDir.mkdirs()
                    }
                    val outputFile = File(outputDir, "$packageName.apk")
                    FileInputStream(File(sourcePath)).use { input ->
                        FileOutputStream(outputFile).use { output ->
                            val buffer = ByteArray(4 * 1024)
                            var byteCount: Int
                            while (input.read(buffer).also { byteCount = it } > 0) {
                                output.write(buffer, 0, byteCount)
                            }
                            output.flush()
                        }
                    }
                    result.success(outputFile.absolutePath)
                } catch (e: Exception) {
                    result.error("ERROR", e.localizedMessage, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
