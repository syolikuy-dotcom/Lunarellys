package com.lunarellys.music

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val CHANNEL = "com.lunarellys.music/permissions"
        private const val REQ_NOTIFICATION = 4101
        private const val REQ_BLUETOOTH = 4102
        private const val REQ_MICROPHONE = 4103
        private const val REQ_PICK_IMAGE = 4104

        private val APP_ICON_ALIASES = mapOf(
            "bawaan" to "com.lunarellys.music.IconBawaan",
            "malam" to "com.lunarellys.music.IconMalam",
            "kaca" to "com.lunarellys.music.IconKaca",
            "emas" to "com.lunarellys.music.IconEmas",
            "hutan" to "com.lunarellys.music.IconHutan",
            "samudra" to "com.lunarellys.music.IconSamudra",
            "senja" to "com.lunarellys.music.IconSenja",
            "piringan" to "com.lunarellys.music.IconPiringan",
            "neon" to "com.lunarellys.music.IconNeon",
            "gema" to "com.lunarellys.music.IconGema",
            "bintang" to "com.lunarellys.music.IconBintang",
            "aurora" to "com.lunarellys.music.IconAurora",
            "sakura" to "com.lunarellys.music.IconSakura",
            "mono" to "com.lunarellys.music.IconMono",
            "kopi" to "com.lunarellys.music.IconKopi",
            "ruby" to "com.lunarellys.music.IconRuby",
            "zamrud" to "com.lunarellys.music.IconZamrud",
            "siber" to "com.lunarellys.music.IconSiber",
            "pastel" to "com.lunarellys.music.IconPastel",
            "baja" to "com.lunarellys.music.IconBaja"
        )

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
    private var pendingImageResult: MethodChannel.Result? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val lp = window.attributes
            lp.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            window.attributes = lp
        }
    }

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
                                presetKey = args["presetKey"] as? String ?: prev.presetKey,
                                islandScale = (args["islandScale"] as? Number)?.toFloat() ?: prev.islandScale,
                                islandYOffset = (args["islandYOffset"] as? Number)?.toFloat() ?: prev.islandYOffset,
                                showLyrics = args["showLyrics"] as? Boolean ?: prev.showLyrics,
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

                "setAppIcon" -> {
                    val args = call.arguments as? Map<*, *>
                    val requestedKey = (args?.get("key") as? String)?.lowercase() ?: "bawaan"
                    val targetCls = APP_ICON_ALIASES[requestedKey] ?: APP_ICON_ALIASES["bawaan"]!!
                    try {
                        val pm = packageManager
                        for ((_, clsName) in APP_ICON_ALIASES) {
                            val newState = if (clsName == targetCls) {
                                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                            } else {
                                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                            }
                            pm.setComponentEnabledSetting(
                                ComponentName(this, clsName),
                                newState,
                                PackageManager.DONT_KILL_APP
                            )
                        }
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }

                "pickMediaImage" -> {
                    pendingImageResult?.success(null)
                    pendingImageResult = result
                    try {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "image/*"
                        }
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, REQ_PICK_IMAGE)
                    } catch (_: Exception) {
                        pendingImageResult?.success(null)
                        pendingImageResult = null
                    }
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

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_PICK_IMAGE) {
            val res = pendingImageResult
            pendingImageResult = null
            if (res == null) return
            val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
            if (uri == null) {
                res.success(null)
                return
            }
            Thread {
                val copiedPath = try {
                    val dest = File(cacheDir, "poster_picked_${System.currentTimeMillis()}.jpg")
                    contentResolver.openInputStream(uri)?.use { input ->
                        FileOutputStream(dest).use { output ->
                            input.copyTo(output)
                        }
                    }
                    if (dest.exists() && dest.length() > 0L) dest.absolutePath else null
                } catch (_: Exception) {
                    null
                }
                runOnUiThread { res.success(copiedPath) }
            }.start()
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
