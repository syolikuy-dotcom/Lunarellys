package com.lunarellys.music

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val CHANNEL = "com.lunarellys.music/permissions"
        private const val REQ_NOTIFICATION = 4101
        private const val REQ_BLUETOOTH = 4102
        private const val REQ_MICROPHONE = 4103

        @Volatile
        private var sharedOverlayController: DynamicIslandOverlayController? = null

        private fun getOverlayController(activity: MainActivity): DynamicIslandOverlayController {
            return sharedOverlayController ?: synchronized(this) {
                sharedOverlayController ?: DynamicIslandOverlayController(activity.applicationContext)
                    .also { sharedOverlayController = it }
            }
        }
    }

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingRequestCode: Int = 0
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val overlay = getOverlayController(this)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        overlay.onActionListener = { action, seekMs ->
            runOnUiThread {
                val payload = if (action == "seek" && seekMs != null) {
                    "seek:$seekMs"
                } else {
                    action
                }
                methodChannel?.invokeMethod("onDynamicIslandAction", payload)
            }
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkStatuses" -> result.success(collectStatuses())

                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                        result.success(true)
                    } else if (isPermissionGranted(Manifest.permission.POST_NOTIFICATIONS)) {
                        result.success(true)
                    } else {
                        requestSinglePermission(
                            Manifest.permission.POST_NOTIFICATIONS,
                            REQ_NOTIFICATION,
                            result
                        )
                    }
                }

                "requestBluetoothPermission" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                        result.success(true)
                    } else if (isPermissionGranted(Manifest.permission.BLUETOOTH_CONNECT)) {
                        result.success(true)
                    } else {
                        requestSinglePermission(
                            Manifest.permission.BLUETOOTH_CONNECT,
                            REQ_BLUETOOTH,
                            result
                        )
                    }
                }

                "requestMicrophonePermission" -> {
                    if (isPermissionGranted(Manifest.permission.RECORD_AUDIO)) {
                        result.success(true)
                    } else {
                        requestSinglePermission(
                            Manifest.permission.RECORD_AUDIO,
                            REQ_MICROPHONE,
                            result
                        )
                    }
                }

                "requestOverlayPermission" -> {
                    if (overlay.canDrawOverlays()) {
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        try {
                            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(fallback)
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                }

                "requestBatteryOptimizationExemption" -> {
                    try {
                        if (isBatteryOptimizationIgnored()) {
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        try {
                            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                }

                "openNotificationSettings" -> {
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            }
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }

                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }

                "updateDynamicIsland", "updatePlaybackAndLyrics" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args != null) {
                        val prev = ArchysMediaOverlayStore.state
                        val accentNum = (args["accentColor"] as? Number)?.toLong()
                        val accentInt = accentNum?.toInt() ?: prev.accentColor
                        val trackId = args["trackId"] as? String ?: prev.trackId
                        val rawLyrics = args["lyrics"] as? List<*>
                        val parsedLyrics = if (rawLyrics != null) {
                            rawLyrics.mapNotNull { entry ->
                                val m = entry as? Map<*, *> ?: return@mapNotNull null
                                val text = (m["text"] as? String)?.trim().orEmpty()
                                if (text.isEmpty()) return@mapNotNull null
                                val timeMs = (m["timeMs"] as? Number)?.toInt()
                                val sec = (m["secondary"] as? String)?.trim()?.takeIf { it.isNotEmpty() }
                                LyricLineData(timeMs = timeMs, text = text, secondary = sec)
                            }
                        } else if (trackId != prev.trackId) {
                            emptyList()
                        } else {
                            prev.lyrics
                        }

                        ArchysMediaOverlayStore.updateState(
                            ArchysPlaybackState(
                                enabled = args["enabled"] as? Boolean ?: prev.enabled,
                                alwaysVisible = args["alwaysVisible"] as? Boolean ?: prev.alwaysVisible,
                                systemOverlayEnabled =
                                    args["systemOverlayEnabled"] as? Boolean ?: prev.systemOverlayEnabled,
                                positionMode = args["positionMode"] as? String ?: prev.positionMode,
                                lockScreenLyricsEnabled =
                                    args["lockScreenLyricsEnabled"] as? Boolean ?: prev.lockScreenLyricsEnabled,
                                hasTrack = args["hasTrack"] as? Boolean ?: false,
                                trackId = trackId,
                                title = (args["title"] as? String)?.ifBlank { "Archys" } ?: "Archys",
                                artist = args["artist"] as? String ?: "",
                                artUrl = args["artUrl"] as? String ?: "",
                                isPlaying = args["isPlaying"] as? Boolean ?: false,
                                positionMs = (args["positionMs"] as? Number)?.toLong() ?: prev.positionMs,
                                durationMs = (args["durationMs"] as? Number)?.toLong() ?: prev.durationMs,
                                syncedAtElapsedMs = android.os.SystemClock.elapsedRealtime(),
                                lyricsOffsetMs = (args["lyricsOffsetMs"] as? Number)?.toInt() ?: prev.lyricsOffsetMs,
                                accentColor = accentInt,
                                lyrics = parsedLyrics
                            )
                        )
                    }
                    result.success(true)
                }

                "openLockScreenPreview" -> {
                    overlay.launchLockScreenActivity(preview = true)
                    result.success(true)
                }

                "hideSystemDynamicIsland" -> {
                    overlay.hideNow()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onStart() {
        super.onStart()
        getOverlayController(this).setAppForeground(true)
    }

    override fun onResume() {
        super.onResume()
        getOverlayController(this).setAppForeground(true)
    }

    override fun onStop() {
        super.onStop()
        getOverlayController(this).setAppForeground(false)
    }

    override fun onDestroy() {
        if (isFinishing) {
            sharedOverlayController?.onActionListener = null
        }
        methodChannel = null
        super.onDestroy()
    }

    private fun requestSinglePermission(
        permission: String,
        requestCode: Int,
        result: MethodChannel.Result
    ) {
        pendingPermissionResult?.success(false)
        pendingPermissionResult = result
        pendingRequestCode = requestCode
        ActivityCompat.requestPermissions(this, arrayOf(permission), requestCode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == pendingRequestCode && pendingPermissionResult != null) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
            pendingRequestCode = 0
        }
    }

    private fun isPermissionGranted(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(this, permission) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun isBatteryOptimizationIgnored(): Boolean {
        val pm = getSystemService(POWER_SERVICE) as? PowerManager ?: return true
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    private fun collectStatuses(): Map<String, Any> {
        val notificationsGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            isPermissionGranted(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            true
        }
        val bluetoothGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            isPermissionGranted(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            true
        }
        val microphoneGranted = isPermissionGranted(Manifest.permission.RECORD_AUDIO)
        val overlayGranted = getOverlayController(this).canDrawOverlays()

        return mapOf(
            "notificationsGranted" to notificationsGranted,
            "batteryOptimizationIgnored" to isBatteryOptimizationIgnored(),
            "bluetoothGranted" to bluetoothGranted,
            "microphoneGranted" to microphoneGranted,
            "overlayGranted" to overlayGranted,
            "sdkInt" to Build.VERSION.SDK_INT
        )
    }
}
