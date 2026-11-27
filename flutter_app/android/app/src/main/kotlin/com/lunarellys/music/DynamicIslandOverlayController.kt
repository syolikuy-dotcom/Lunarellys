package com.lunarellys.music

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.Icon
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.core.content.ContextCompat
import kotlin.math.abs

class DynamicIslandOverlayController(context: Context) {

    private val appContext: Context = context.applicationContext
    private val windowManager: WindowManager? =
        appContext.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
    private val mainHandler = Handler(Looper.getMainLooper())

    private var appInForeground = true
    private var expanded = false
    private var manuallyDismissedInSession = false
    private var userDraggedOffsetX = 0
    private var userDraggedOffsetY = 0
    private var hasUserDragged = false
    private var lastTrackId = ""
    private var receiverRegistered = false

    private var rootView: FrameLayout? = null
    private var glassCard: LinearLayout? = null
    private var compactContainer: LinearLayout? = null
    private var expandedContainer: LinearLayout? = null

    private var compactArtView: RoundedArtworkView? = null
    private var compactTitleView: TextView? = null
    private var compactEqView: NativeEqualizerView? = null

    private var expandedArtView: RoundedArtworkView? = null
    private var expandedTitleView: TextView? = null
    private var expandedArtistView: TextView? = null
    private var expandedEqView: NativeEqualizerView? = null
    private var expandedPlayBtn: VectorMediaButton? = null
    private var expandedPlayCircle: FrameLayout? = null
    private var expandedProgressBar: ProgressBar? = null
    private var expandedElapsedView: TextView? = null
    private var expandedRemainingView: TextView? = null

    var onActionListener: ((String, Long?) -> Unit)? = null

    companion object {
        private const val LOCK_NOTIF_CHANNEL_ID = "archys_lockscreen_lyrics"
        private const val LOCK_NOTIF_ID = 7402
        private const val ACTION_LOCK_TOGGLE = "com.lunarellys.music.LOCK_ACTION_TOGGLE"
        private const val ACTION_LOCK_NEXT = "com.lunarellys.music.LOCK_ACTION_NEXT"
    }

    private val notificationManager: NotificationManager? =
        appContext.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
    private var lastNotifKey = ""

    private val progressTicker = object : Runnable {
        override fun run() {
            if (!expanded || rootView?.isAttachedToWindow != true) return
            updateExpandedProgressOnly()
            mainHandler.postDelayed(this, 500L)
        }
    }

    private val lyricNotifTicker = object : Runnable {
        override fun run() {
            val st = ArchysMediaOverlayStore.state
            if (!st.lockScreenLyricsEnabled || !st.hasTrack || !st.isPlaying) return
            syncLockScreenNotification()
            mainHandler.postDelayed(this, 450L)
        }
    }

    private val stateListener: (ArchysPlaybackState) -> Unit = { newState ->
        mainHandler.post {
            val trackChanged = newState.hasTrack &&
                (newState.trackId != lastTrackId || newState.title != compactTitleView?.text?.toString())
            if (newState.trackId.isNotBlank()) {
                lastTrackId = newState.trackId
            }
            if (trackChanged) {
                manuallyDismissedInSession = false
            }
            if (!appInForeground) {
                refreshVisibility()
            }
            syncLockScreenNotification()
            rescheduleLyricNotifTicker(newState)
        }
    }

    private val artListener: (String, Bitmap) -> Unit = { url, bmp ->
        mainHandler.post {
            val st = ArchysMediaOverlayStore.state
            if (st.artUrl == url) {
                if (rootView?.isAttachedToWindow == true) {
                    compactArtView?.setArtworkBitmap(bmp)
                    expandedArtView?.setArtworkBitmap(bmp)
                }
                syncLockScreenNotification()
            }
        }
    }

    private val screenLockReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.action ?: return
            when (action) {
                Intent.ACTION_USER_PRESENT -> {
                    LockScreenPlayerActivity.dismissActiveIfUnlocked()
                }
                ACTION_LOCK_TOGGLE -> {
                    ArchysMediaOverlayStore.dispatchAction("toggle")
                }
                ACTION_LOCK_NEXT -> {
                    ArchysMediaOverlayStore.dispatchAction("next")
                }
            }
        }
    }

    init {
        ensureNotificationChannel()
        ArchysMediaOverlayStore.addStateListener(stateListener)
        ArchysMediaOverlayStore.addArtListener(artListener)
        ArchysMediaOverlayStore.actionListener = { action, seekMs ->
            val listener = onActionListener
            if (listener != null) {
                listener.invoke(action, seekMs)
            } else {
                val key = when (action) {
                    "prev" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
                    "next" -> KeyEvent.KEYCODE_MEDIA_NEXT
                    "toggle" -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
                    else -> 0
                }
                if (key != 0) {
                    try {
                        val am = appContext.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                        am?.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, key))
                        am?.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, key))
                    } catch (_: Exception) {}
                }
            }
            if (action == "open") {
                launchApp()
            }
        }
        registerScreenReceiver()
    }

    private fun registerScreenReceiver() {
        if (receiverRegistered) return
        try {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_USER_PRESENT)
                addAction(ACTION_LOCK_TOGGLE)
                addAction(ACTION_LOCK_NEXT)
            }
            ContextCompat.registerReceiver(
                appContext,
                screenLockReceiver,
                filter,
                ContextCompat.RECEIVER_NOT_EXPORTED
            )
            receiverRegistered = true
        } catch (_: Exception) {
        }
    }

    private fun canPostNotifications(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                appContext,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = notificationManager ?: return
        try {
            val existing = nm.getNotificationChannel(LOCK_NOTIF_CHANNEL_ID)
            if (existing != null) return
            val channel = NotificationChannel(
                LOCK_NOTIF_CHANNEL_ID,
                "Lirik Lock Screen",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notifikasi lirik tersinkronisasi untuk membuka panel lirik di layar kunci"
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
            }
            nm.createNotificationChannel(channel)
        } catch (_: Exception) {
        }
    }

    private fun rescheduleLyricNotifTicker(st: ArchysPlaybackState) {
        mainHandler.removeCallbacks(lyricNotifTicker)
        if (st.lockScreenLyricsEnabled && st.hasTrack && st.isPlaying && st.lyrics.any { it.timeMs != null }) {
            mainHandler.postDelayed(lyricNotifTicker, 450L)
        }
    }

    private fun syncLockScreenNotification() {
        val nm = notificationManager ?: return
        val st = ArchysMediaOverlayStore.state
        if (!st.lockScreenLyricsEnabled || !st.hasTrack || !canPostNotifications()) {
            if (lastNotifKey.isNotEmpty()) {
                lastNotifKey = ""
                try {
                    nm.cancel(LOCK_NOTIF_ID)
                } catch (_: Exception) {
                }
            }
            return
        }

        val activeIdx = st.activeLyricIndex()
        val artBmp = ArchysMediaOverlayStore.getCachedBitmap(st.artUrl)
        val key = "${st.trackId}|${st.title}|${st.artist}|${st.isPlaying}|$activeIdx|${artBmp != null}|${st.lyrics.size}"
        if (key == lastNotifKey) return
        lastNotifKey = key

        ensureNotificationChannel()

        val openIntent = Intent(appContext, LockScreenPlayerActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION
            )
            putExtra(LockScreenPlayerActivity.EXTRA_PREVIEW_MODE, false)
        }
        val openPending = PendingIntent.getActivity(
            appContext,
            7410,
            openIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val toggleIntent = Intent(ACTION_LOCK_TOGGLE).apply {
            setPackage(appContext.packageName)
        }
        val togglePending = PendingIntent.getBroadcast(
            appContext,
            7411,
            toggleIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val nextIntent = Intent(ACTION_LOCK_NEXT).apply {
            setPackage(appContext.packageName)
        }
        val nextPending = PendingIntent.getBroadcast(
            appContext,
            7412,
            nextIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val currentLine = when {
            activeIdx in st.lyrics.indices -> st.lyrics[activeIdx].text
            st.lyrics.isNotEmpty() -> st.lyrics.first().text
            else -> "Ketuk Buka Lirik untuk menampilkan lirik"
        }

        val expandedSnippet = buildString {
            if (activeIdx in st.lyrics.indices) {
                if (activeIdx - 1 >= 0) {
                    append(st.lyrics[activeIdx - 1].text).append('\n')
                }
                append("▶ ").append(st.lyrics[activeIdx].text)
                if (activeIdx + 1 < st.lyrics.size) {
                    append('\n').append(st.lyrics[activeIdx + 1].text)
                }
            } else if (st.lyrics.isNotEmpty()) {
                val preview = st.lyrics.take(3).joinToString("\n") { it.text }
                append(preview)
            } else {
                append("Ketuk Buka Lirik untuk membuka panel lirik di layar kunci")
            }
        }

        val trackTitle = st.title.ifBlank { "Archys" }
        val subtitleHeader = if (st.artist.isNotBlank()) "$trackTitle · ${st.artist}" else trackTitle

        try {
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(appContext, LOCK_NOTIF_CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(appContext)
            }

            builder.setSmallIcon(R.drawable.ic_stat_archys)
                .setContentTitle(subtitleHeader)
                .setContentText(currentLine)
                .setStyle(Notification.BigTextStyle().bigText(expandedSnippet))
                .setContentIntent(openPending)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setOngoing(st.isPlaying)
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
                .setColor(st.accentColor)

            if (artBmp != null) {
                builder.setLargeIcon(artBmp)
            }

            val openAction = Notification.Action.Builder(
                Icon.createWithResource(appContext, R.drawable.ic_stat_archys),
                "Buka Lirik",
                openPending
            ).build()
            val toggleAction = Notification.Action.Builder(
                Icon.createWithResource(appContext, R.drawable.ic_stat_archys),
                if (st.isPlaying) "Jeda" else "Putar",
                togglePending
            ).build()
            val nextAction = Notification.Action.Builder(
                Icon.createWithResource(appContext, R.drawable.ic_stat_archys),
                "Berikutnya",
                nextPending
            ).build()

            builder.addAction(openAction)
            builder.addAction(toggleAction)
            builder.addAction(nextAction)

            nm.notify(LOCK_NOTIF_ID, builder.build())
        } catch (_: Exception) {
        }
    }

    fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(appContext)
        } else {
            true
        }
    }

    fun setAppForeground(inForeground: Boolean) {
        mainHandler.post {
            appInForeground = inForeground
            if (inForeground) {
                expanded = false
                manuallyDismissedInSession = false
                hasUserDragged = false
                hideInternal()
            } else {
                refreshVisibility()
            }
        }
    }

    fun hideNow() {
        mainHandler.post {
            expanded = false
            hideInternal()
        }
    }

    fun launchLockScreenActivity(preview: Boolean) {
        try {
            val intent = Intent(appContext, LockScreenPlayerActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION
                )
                putExtra(LockScreenPlayerActivity.EXTRA_PREVIEW_MODE, preview)
            }
            appContext.startActivity(intent)
        } catch (_: Exception) {
        }
    }

    private fun shouldShowOutsideApp(): Boolean {
        val st = ArchysMediaOverlayStore.state
        if (appInForeground) return false
        if (!st.enabled || !st.systemOverlayEnabled) return false
        if (manuallyDismissedInSession) return false
        if (!canDrawOverlays()) return false
        return st.hasTrack || st.alwaysVisible
    }

    private fun refreshVisibility() {
        if (shouldShowOutsideApp()) {
            showOrUpdateInternal()
        } else {
            hideInternal()
        }
    }

    private fun dp(value: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value,
            appContext.resources.displayMetrics
        ).toInt()
    }

    private fun dpF(value: Float): Float {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value,
            appContext.resources.displayMetrics
        )
    }

    private fun screenWidthPx(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && windowManager != null) {
            windowManager.currentWindowMetrics.bounds.width()
        } else {
            appContext.resources.displayMetrics.widthPixels
        }
    }

    private fun statusBarHeightPx(): Int {
        val resId = appContext.resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (resId > 0) appContext.resources.getDimensionPixelSize(resId) else dp(28f)
    }

    private fun safeTopInsetPx(): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && windowManager != null) {
            try {
                val insets = windowManager.currentWindowMetrics.windowInsets.getInsetsIgnoringVisibility(
                    WindowInsets.Type.statusBars() or WindowInsets.Type.displayCutout()
                )
                if (insets.top > 0) return insets.top
            } catch (_: Exception) {
            }
        }
        return statusBarHeightPx()
    }

    private fun targetTopYPx(): Int {
        val st = ArchysMediaOverlayStore.state
        val safeTop = safeTopInsetPx()
        if (expanded || st.positionMode != "notch") {
            // Safe below status bar + cutout on 100% of Android phones
            return safeTop + dp(6f)
        }
        // Notch mode: compact capsule sits neatly centered inside status bar height
        val statusH = statusBarHeightPx()
        return ((statusH - dp(26f)) / 2).coerceAtLeast(dp(3f))
    }

    private fun buildParams(): WindowManager.LayoutParams {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS

        val targetY = if (hasUserDragged) userDraggedOffsetY else targetTopYPx()
        val targetX = if (hasUserDragged) userDraggedOffsetX else 0

        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            flags,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            x = targetX
            y = targetY
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
    }

    private fun ensureViewCreated() {
        if (rootView != null) return

        val outer = FrameLayout(appContext).apply {
            clipChildren = false
            clipToPadding = false
        }

        val card = LinearLayout(appContext).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            elevation = dpF(16f)
            clipToPadding = true
            clipChildren = true
        }

        // --- COMPACT CAPSULE ---
        val compact = LinearLayout(appContext).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(7f), dp(5f), dp(9f), dp(5f))
        }

        val cArt = RoundedArtworkView(appContext, dpF(11f)).apply {
            layoutParams = LinearLayout.LayoutParams(dp(22f), dp(22f))
        }

        val cTitle = TextView(appContext).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.2f)
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
            ).apply {
                marginStart = dp(8f)
                marginEnd = dp(8f)
            }
        }

        val cEq = NativeEqualizerView(appContext).apply {
            layoutParams = LinearLayout.LayoutParams(dp(15f), dp(13f))
        }

        compact.addView(cArt)
        compact.addView(cTitle)
        compact.addView(cEq)

        // --- EXPANDED LIQUID GLASS CARD ---
        val expandedBox = LinearLayout(appContext).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16f), dp(14f), dp(16f), dp(14f))
            visibility = View.GONE
        }

        val headerRow = LinearLayout(appContext).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val eArt = RoundedArtworkView(appContext, dpF(13f)).apply {
            layoutParams = LinearLayout.LayoutParams(dp(48f), dp(48f))
        }

        val metaCol = LinearLayout(appContext).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
            ).apply {
                marginStart = dp(12f)
                marginEnd = dp(8f)
            }
        }

        val eTitle = TextView(appContext).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14.8f)
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }

        val eArtist = TextView(appContext).apply {
            setTextColor(0xB8FFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.2f)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }

        metaCol.addView(eTitle)
        metaCol.addView(eArtist)

        val eEq = NativeEqualizerView(appContext).apply {
            layoutParams = LinearLayout.LayoutParams(dp(18f), dp(16f)).apply {
                marginEnd = dp(8f)
            }
        }

        val openWrap = FrameLayout(appContext).apply {
            layoutParams = LinearLayout.LayoutParams(dp(30f), dp(30f))
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0x24FFFFFF)
            }
            setOnClickListener {
                expanded = false
                ArchysMediaOverlayStore.dispatchAction("open")
            }
            addView(
                VectorMediaButton(appContext, VectorMediaButton.IconKind.OPEN, Color.WHITE).apply {
                    layoutParams = FrameLayout.LayoutParams(dp(16f), dp(16f), Gravity.CENTER)
                }
            )
        }

        headerRow.addView(eArt)
        headerRow.addView(metaCol)
        headerRow.addView(eEq)
        headerRow.addView(openWrap)

        // Progress bar row
        val progressRow = LinearLayout(appContext).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(12f), 0, dp(8f))
        }

        val elapsedTv = TextView(appContext).apply {
            setTextColor(0xA6FFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 10.5f)
            typeface = Typeface.MONOSPACE
            text = "0:00"
        }

        val progressBar = ProgressBar(
            appContext,
            null,
            android.R.attr.progressBarStyleHorizontal
        ).apply {
            max = 1000
            progress = 0
            layoutParams = LinearLayout.LayoutParams(0, dp(4f), 1f).apply {
                marginStart = dp(8f)
                marginEnd = dp(8f)
            }
            progressDrawable = buildProgressDrawable()
        }

        val remainingTv = TextView(appContext).apply {
            setTextColor(0xA6FFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 10.5f)
            typeface = Typeface.MONOSPACE
            text = "-0:00"
        }

        progressRow.addView(elapsedTv)
        progressRow.addView(progressBar)
        progressRow.addView(remainingTv)

        // Transport controls row with crisp custom Canvas vectors
        val controlsRow = LinearLayout(appContext).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, dp(2f), 0, 0)
        }

        val prevBtnWrap = createGlassIconCircle(dp(40f), 0x1FFFFFFF) {
            ArchysMediaOverlayStore.dispatchAction("prev")
        }.apply {
            addView(
                VectorMediaButton(appContext, VectorMediaButton.IconKind.PREV, Color.WHITE).apply {
                    layoutParams = FrameLayout.LayoutParams(dp(20f), dp(20f), Gravity.CENTER)
                }
            )
        }

        val ePlayBtn = VectorMediaButton(appContext, VectorMediaButton.IconKind.PLAY, Color.BLACK).apply {
            layoutParams = FrameLayout.LayoutParams(dp(22f), dp(22f), Gravity.CENTER)
        }
        val playBtnWrap = createGlassIconCircle(dp(46f), Color.WHITE) {
            ArchysMediaOverlayStore.dispatchAction("toggle")
        }.apply {
            addView(ePlayBtn)
        }

        val nextBtnWrap = createGlassIconCircle(dp(40f), 0x1FFFFFFF) {
            ArchysMediaOverlayStore.dispatchAction("next")
        }.apply {
            addView(
                VectorMediaButton(appContext, VectorMediaButton.IconKind.NEXT, Color.WHITE).apply {
                    layoutParams = FrameLayout.LayoutParams(dp(20f), dp(20f), Gravity.CENTER)
                }
            )
        }

        val collapseWrap = createGlassIconCircle(dp(36f), 0x1CFFFFFF) {
            expanded = false
            hasUserDragged = false
            bindViews()
        }.apply {
            addView(
                VectorMediaButton(appContext, VectorMediaButton.IconKind.COLLAPSE, 0xCCFFFFFF.toInt()).apply {
                    layoutParams = FrameLayout.LayoutParams(dp(18f), dp(18f), Gravity.CENTER)
                }
            )
        }

        controlsRow.addView(prevBtnWrap)
        controlsRow.addView(spacer(dp(14f)))
        controlsRow.addView(playBtnWrap)
        controlsRow.addView(spacer(dp(14f)))
        controlsRow.addView(nextBtnWrap)
        controlsRow.addView(spacer(dp(18f)))
        controlsRow.addView(collapseWrap)

        expandedBox.addView(headerRow)
        expandedBox.addView(progressRow)
        expandedBox.addView(controlsRow)

        card.addView(compact)
        card.addView(expandedBox)

        outer.addView(
            card,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(dp(8f), dp(2f), dp(8f), dp(12f))
            }
        )

        attachTouchHandler(outer)

        rootView = outer
        glassCard = card
        compactContainer = compact
        expandedContainer = expandedBox
        compactArtView = cArt
        compactTitleView = cTitle
        compactEqView = cEq
        expandedArtView = eArt
        expandedTitleView = eTitle
        expandedArtistView = eArtist
        expandedEqView = eEq
        expandedPlayBtn = ePlayBtn
        expandedPlayCircle = playBtnWrap
        expandedProgressBar = progressBar
        expandedElapsedView = elapsedTv
        expandedRemainingView = remainingTv
    }

    private fun buildProgressDrawable(): android.graphics.drawable.LayerDrawable {
        val bg = GradientDrawable().apply {
            cornerRadius = dpF(99f)
            setColor(0x3DFFFFFF)
        }
        val fg = GradientDrawable().apply {
            cornerRadius = dpF(99f)
            setColor(Color.WHITE)
        }
        val clip = android.graphics.drawable.ClipDrawable(fg, Gravity.START, android.graphics.drawable.ClipDrawable.HORIZONTAL)
        return android.graphics.drawable.LayerDrawable(arrayOf(bg, clip)).apply {
            setId(0, android.R.id.background)
            setId(1, android.R.id.progress)
        }
    }

    private fun createGlassIconCircle(sizePx: Int, bgColor: Int, onClick: () -> Unit): FrameLayout {
        return FrameLayout(appContext).apply {
            layoutParams = LinearLayout.LayoutParams(sizePx, sizePx)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(bgColor)
            }
            setOnClickListener { onClick() }
        }
    }

    private fun spacer(widthPx: Int): View {
        return View(appContext).apply {
            layoutParams = LinearLayout.LayoutParams(widthPx, 1)
        }
    }

    private fun attachTouchHandler(view: View) {
        var downX = 0f
        var downY = 0f
        var startWinX = 0
        var startWinY = 0
        var moved = false

        view.setOnTouchListener { v, event ->
            val lp = v.layoutParams as? WindowManager.LayoutParams ?: return@setOnTouchListener false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX
                    downY = event.rawY
                    startWinX = lp.x
                    startWinY = lp.y
                    moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - downX
                    val dy = event.rawY - downY
                    if (abs(dx) > dp(6f) || abs(dy) > dp(6f)) {
                        moved = true
                        hasUserDragged = true
                        lp.x = (startWinX + dx.toInt()).coerceIn(-dp(110f), dp(110f))
                        lp.y = (startWinY + dy.toInt()).coerceIn(dp(3f), dp(260f))
                        userDraggedOffsetX = lp.x
                        userDraggedOffsetY = lp.y
                        try {
                            windowManager?.updateViewLayout(v, lp)
                        } catch (_: Exception) {}
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val dy = event.rawY - downY
                    if (!moved) {
                        expanded = !expanded
                        if (!expanded) {
                            hasUserDragged = false
                        }
                        bindViews()
                    } else if (dy < -dp(58f)) {
                        manuallyDismissedInSession = true
                        expanded = false
                        hasUserDragged = false
                        hideInternal()
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun formatTime(ms: Long): String {
        val sec = (ms / 1000L).coerceAtLeast(0L)
        val m = sec / 60L
        val s = sec % 60L
        return "$m:${s.toString().padStart(2, '0')}"
    }

    private fun updateExpandedProgressOnly() {
        val st = ArchysMediaOverlayStore.state
        val pos = st.currentPositionMs()
        val dur = st.durationMs.coerceAtLeast(0L)
        if (dur > 0L) {
            val pct = ((pos.toFloat() / dur.toFloat()) * 1000f).toInt().coerceIn(0, 1000)
            expandedProgressBar?.progress = pct
            expandedElapsedView?.text = formatTime(pos)
            val rem = (dur - pos).coerceAtLeast(0L)
            expandedRemainingView?.text = "-${formatTime(rem)}"
        } else {
            expandedProgressBar?.progress = 0
            expandedElapsedView?.text = formatTime(pos)
            expandedRemainingView?.text = "--:--"
        }
    }

    private fun bindViews() {
        val root = rootView ?: return
        val card = glassCard ?: return
        val st = ArchysMediaOverlayStore.state
        val accent = st.accentColor
        val screenW = screenWidthPx()
        val isNotchCompact = !expanded && st.positionMode == "notch"

        // Liquid Glass background drawable
        card.background = LiquidGlassCapsuleDrawable(
            cornerRadiusPx = dpF(if (expanded) 28f else 99f),
            accentColor = accent,
            borderWidthPx = dpF(1.15f),
            expandedStyle = expanded
        )

        // Sizing adapted safely to any screen width
        val compactTargetWidth = if (isNotchCompact) {
            dp(96f).coerceAtMost((screenW * 0.28f).toInt())
        } else {
            val maxSafeW = (screenW - dp(84f)).coerceAtLeast(dp(168f))
            if (st.hasTrack) dp(212f).coerceAtMost(maxSafeW) else dp(156f)
        }
        val expandedTargetWidth = (screenW - dp(28f)).coerceIn(dp(280f), dp(376f))

        card.layoutParams = (card.layoutParams as FrameLayout.LayoutParams).apply {
            width = if (expanded) expandedTargetWidth else compactTargetWidth
        }

        // Artwork bitmap
        val cachedBmp = ArchysMediaOverlayStore.getCachedBitmap(st.artUrl)
        compactArtView?.setArtworkBitmap(cachedBmp)
        expandedArtView?.setArtworkBitmap(cachedBmp)

        // Compact layout adjustments for notch vs below mode
        compactContainer?.setPadding(
            dp(if (isNotchCompact) 5f else 7f),
            dp(if (isNotchCompact) 3f else 5f),
            dp(if (isNotchCompact) 7f else 9f),
            dp(if (isNotchCompact) 3f else 5f)
        )
        compactArtView?.layoutParams = (compactArtView?.layoutParams as LinearLayout.LayoutParams).apply {
            val s = dp(if (isNotchCompact) 17f else 22f)
            width = s
            height = s
        }
        compactTitleView?.visibility = if (isNotchCompact) View.GONE else View.VISIBLE
        compactTitleView?.text = if (st.hasTrack && st.title.isNotBlank()) st.title else "Archys"

        val eqColor = if (st.hasTrack) accent else 0xFF34C759.toInt()
        compactEqView?.update(st.isPlaying, eqColor)
        expandedEqView?.update(st.isPlaying, eqColor)

        expandedTitleView?.text = if (st.hasTrack && st.title.isNotBlank()) st.title else "Archys Music"
        expandedArtistView?.text = if (st.hasTrack && st.artist.isNotBlank()) {
            st.artist
        } else {
            "Siap memutar musik"
        }
        expandedPlayBtn?.apply {
            iconKind = if (st.isPlaying) VectorMediaButton.IconKind.PAUSE else VectorMediaButton.IconKind.PLAY
            invalidate()
        }

        compactContainer?.visibility = if (expanded) View.GONE else View.VISIBLE
        expandedContainer?.visibility = if (expanded) View.VISIBLE else View.GONE

        updateExpandedProgressOnly()
        mainHandler.removeCallbacks(progressTicker)
        if (expanded && root.isAttachedToWindow) {
            mainHandler.postDelayed(progressTicker, 500L)
        }

        if (root.isAttachedToWindow) {
            try {
                val lp = root.layoutParams as? WindowManager.LayoutParams
                if (lp != null) {
                    if (!hasUserDragged) {
                        lp.x = 0
                        lp.y = targetTopYPx()
                    }
                    windowManager?.updateViewLayout(root, lp)
                }
            } catch (_: Exception) {
            }
        }
    }

    private fun showOrUpdateInternal() {
        val wm = windowManager ?: return
        ensureViewCreated()
        bindViews()
        val view = rootView ?: return
        if (!view.isAttachedToWindow) {
            try {
                view.alpha = 0f
                view.scaleX = 0.92f
                view.scaleY = 0.92f
                wm.addView(view, buildParams())
                view.animate()
                    .alpha(1f)
                    .scaleX(1f)
                    .scaleY(1f)
                    .setDuration(220L)
                    .start()
                if (expanded) {
                    mainHandler.postDelayed(progressTicker, 500L)
                }
            } catch (_: Exception) {
            }
        }
    }

    private fun hideInternal() {
        mainHandler.removeCallbacks(progressTicker)
        val wm = windowManager ?: return
        val view = rootView ?: return
        if (view.isAttachedToWindow) {
            try {
                wm.removeViewImmediate(view)
            } catch (_: Exception) {
                try {
                    wm.removeView(view)
                } catch (_: Exception) {}
            }
        }
    }

    private fun launchApp() {
        try {
            val intent = appContext.packageManager.getLaunchIntentForPackage(appContext.packageName)
            if (intent != null) {
                intent.addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                )
                appContext.startActivity(intent)
            }
        } catch (_: Exception) {}
    }
}
