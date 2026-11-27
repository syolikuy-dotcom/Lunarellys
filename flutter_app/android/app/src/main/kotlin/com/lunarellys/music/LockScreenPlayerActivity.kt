package com.lunarellys.music

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.ClipDrawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.TextView
import java.lang.ref.WeakReference
import java.util.Locale

class LockScreenPlayerActivity : Activity() {

    companion object {
        const val EXTRA_PREVIEW_MODE = "preview_mode"

        @Volatile
        private var activeRef: WeakReference<LockScreenPlayerActivity>? = null

        fun dismissActiveIfUnlocked() {
            val act = activeRef?.get() ?: return
            if (!act.isPreviewMode && !act.isFinishing) {
                act.runOnUiThread {
                    act.finishSmoothly()
                }
            }
        }
    }

    private var isPreviewMode = false
    private val mainHandler = Handler(Looper.getMainLooper())
    private var lastTrackKey = ""
    private var lastActiveLyricIdx = -2
    private var isUserSeeking = false

    private lateinit var rootFrame: FrameLayout
    private lateinit var backdropScrim: View
    private lateinit var topContentLayout: LinearLayout
    private lateinit var lyricsScrollView: ScrollView
    private lateinit var lyricsContainer: LinearLayout
    private lateinit var emptyLyricsView: TextView
    private lateinit var glassCard: LinearLayout
    private lateinit var artView: RoundedArtworkView
    private lateinit var titleView: TextView
    private lateinit var artistView: TextView
    private lateinit var eqView: NativeEqualizerView
    private lateinit var seekBar: SeekBar
    private lateinit var elapsedView: TextView
    private lateinit var remainingView: TextView
    private lateinit var playBtn: VectorMediaButton

    private val lyricLineViews = mutableListOf<TextView>()
    private var renderedLyricsRef: List<LyricLineData> = emptyList()

    private val stateListener: (ArchysPlaybackState) -> Unit = { st ->
        runOnUiThread {
            bindState(st, rebuildLyricsIfNeeded = true)
        }
    }

    private val artListener: (String, Bitmap) -> Unit = { url, bmp ->
        runOnUiThread {
            if (ArchysMediaOverlayStore.state.artUrl == url) {
                applyArtworkBitmap(bmp)
            }
        }
    }

    private val ticker = object : Runnable {
        override fun run() {
            if (isFinishing) return
            val st = ArchysMediaOverlayStore.state
            updateTimeAndLyricSpotlight(st)
            mainHandler.postDelayed(this, 220L)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        activeRef = WeakReference(this)
        isPreviewMode = intent?.getBooleanExtra(EXTRA_PREVIEW_MODE, false) == true

        configureLockScreenWindow()
        buildUi()
        setContentView(rootFrame)

        ArchysMediaOverlayStore.addStateListener(stateListener)
        ArchysMediaOverlayStore.addArtListener(artListener)

        bindState(ArchysMediaOverlayStore.state, rebuildLyricsIfNeeded = true)
        mainHandler.post(ticker)
    }

    override fun onNewIntent(intent: android.content.Intent?) {
        super.onNewIntent(intent)
        if (intent != null) {
            isPreviewMode = intent.getBooleanExtra(EXTRA_PREVIEW_MODE, false)
        }
        bindState(ArchysMediaOverlayStore.state, rebuildLyricsIfNeeded = true)
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(ticker)
        ArchysMediaOverlayStore.removeStateListener(stateListener)
        ArchysMediaOverlayStore.removeArtListener(artListener)
        if (activeRef?.get() === this) {
            activeRef = null
        }
        super.onDestroy()
    }

    private fun configureLockScreenWindow() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(false)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
        }

        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT

        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes = window.attributes.apply {
                layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
    }

    private fun dp(value: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value,
            resources.displayMetrics
        ).toInt()
    }

    private fun dpF(value: Float): Float {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value,
            resources.displayMetrics
        )
    }

    private fun safeTopInsetPx(): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val insets = windowManager.currentWindowMetrics.windowInsets.getInsetsIgnoringVisibility(
                    WindowInsets.Type.statusBars() or WindowInsets.Type.displayCutout()
                )
                if (insets.top > 0) return insets.top
            } catch (_: Exception) {
            }
        }
        val resId = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (resId > 0) resources.getDimensionPixelSize(resId) else dp(30f)
    }

    private fun safeBottomInsetPx(): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val insets = windowManager.currentWindowMetrics.windowInsets.getInsetsIgnoringVisibility(
                    WindowInsets.Type.navigationBars()
                )
                if (insets.bottom > 0) return insets.bottom
            } catch (_: Exception) {
            }
        }
        val resId = resources.getIdentifier("navigation_bar_height", "dimen", "android")
        return if (resId > 0) resources.getDimensionPixelSize(resId) else dp(16f)
    }

    private fun buildUi() {
        // Transparent root over the user's real device wallpaper (Theme.Wallpaper.NoTitleBar)
        rootFrame = FrameLayout(this)

        backdropScrim = View(this)
        rootFrame.addView(
            backdropScrim,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )

        val topSafe = safeTopInsetPx() + dp(12f)
        val bottomSafe = safeBottomInsetPx() + dp(14f)

        topContentLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18f), topSafe, dp(18f), bottomSafe)
        }

        // 1. Adaptive Top Header: Album Art + Track Meta + Eq + Tutup Pill
        val headerBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12f), dp(10f), dp(12f), dp(10f))
            background = GradientDrawable().apply {
                cornerRadius = dpF(22f)
                setColor(0x9A121722.toInt())
                setStroke(dp(1f), 0x2EFFFFFF)
            }
        }

        artView = RoundedArtworkView(this, dpF(11f)).apply {
            layoutParams = LinearLayout.LayoutParams(dp(46f), dp(46f))
        }

        val metaCol = LinearLayout(this).apply {
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

        titleView = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15.5f)
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }

        artistView = TextView(this).apply {
            setTextColor(0xB8FFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.8f)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }

        metaCol.addView(titleView)
        metaCol.addView(artistView)

        eqView = NativeEqualizerView(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(17f), dp(14f)).apply {
                marginEnd = dp(10f)
            }
        }

        val closePill = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(11f), dp(7f), dp(12f), dp(7f))
            background = GradientDrawable().apply {
                cornerRadius = dpF(99f)
                setColor(0x2BFFFFFF)
                setStroke(dp(1f), 0x38FFFFFF)
            }
            setOnClickListener { finishSmoothly() }
        }

        val closeIcon = VectorMediaButton(this, VectorMediaButton.IconKind.CLOSE, Color.WHITE).apply {
            layoutParams = LinearLayout.LayoutParams(dp(13f), dp(13f)).apply {
                marginEnd = dp(5f)
            }
        }
        val closeLabel = TextView(this).apply {
            text = "Tutup"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
        }
        closePill.addView(closeIcon)
        closePill.addView(closeLabel)

        headerBar.addView(artView)
        headerBar.addView(metaCol)
        headerBar.addView(eqView)
        headerBar.addView(closePill)
        attachSwipeDownToDismiss(headerBar)

        topContentLayout.addView(headerBar)

        // 2. Center Live Synced Lyrics Viewport
        val lyricsStage = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        }

        lyricsScrollView = ScrollView(this).apply {
            isVerticalScrollBarEnabled = false
            overScrollMode = View.OVER_SCROLL_NEVER
            isVerticalFadingEdgeEnabled = true
            setFadingEdgeLength(dp(38f))
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }

        lyricsContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(6f), dp(28f), dp(6f), dp(36f))
        }
        lyricsScrollView.addView(lyricsContainer)

        emptyLyricsView = TextView(this).apply {
            setTextColor(0xC2FFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(dp(16f), dp(24f), dp(16f), dp(24f))
            visibility = View.GONE
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER
            )
        }

        lyricsStage.addView(lyricsScrollView)
        lyricsStage.addView(emptyLyricsView)
        topContentLayout.addView(lyricsStage)

        // 3. Bottom Compact Translucent Media Control Card (no fake clock or home bar)
        glassCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18f), dp(14f), dp(18f), dp(14f))
            elevation = dpF(14f)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dp(8f)
            }
        }

        seekBar = SeekBar(this).apply {
            max = 1000
            progress = 0
            setPadding(0, dp(4f), 0, dp(4f))
            progressDrawable = buildSeekBarDrawable()
            thumb = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setSize(dp(12f), dp(12f))
                setColor(Color.WHITE)
            }
            splitTrack = false
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(sb: SeekBar?, prog: Int, fromUser: Boolean) {
                    if (fromUser) {
                        val st = ArchysMediaOverlayStore.state
                        if (st.durationMs > 0L) {
                            val targetMs = (st.durationMs * prog / 1000L)
                            elapsedView.text = formatTime(targetMs)
                            remainingView.text = "-${formatTime((st.durationMs - targetMs).coerceAtLeast(0L))}"
                        }
                    }
                }

                override fun onStartTrackingTouch(sb: SeekBar?) {
                    isUserSeeking = true
                }

                override fun onStopTrackingTouch(sb: SeekBar?) {
                    isUserSeeking = false
                    val st = ArchysMediaOverlayStore.state
                    if (st.durationMs > 0L && sb != null) {
                        val targetMs = (st.durationMs * sb.progress / 1000L)
                        ArchysMediaOverlayStore.dispatchAction("seek", targetMs)
                    }
                }
            })
        }

        val timeRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, 0, 0, dp(6f))
        }

        elapsedView = TextView(this).apply {
            setTextColor(0xB8FFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            typeface = Typeface.MONOSPACE
            text = "0:00"
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        remainingView = TextView(this).apply {
            setTextColor(0xB8FFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            typeface = Typeface.MONOSPACE
            gravity = Gravity.END
            text = "-0:00"
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        timeRow.addView(elapsedView)
        timeRow.addView(remainingView)

        val transportRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, dp(2f), 0, dp(2f))
        }

        val prevWrap = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(56f), dp(46f))
            setOnClickListener {
                ArchysMediaOverlayStore.dispatchAction("prev")
            }
            addView(
                VectorMediaButton(this@LockScreenPlayerActivity, VectorMediaButton.IconKind.PREV, Color.WHITE).apply {
                    layoutParams = FrameLayout.LayoutParams(dp(28f), dp(28f), Gravity.CENTER)
                }
            )
        }

        playBtn = VectorMediaButton(this, VectorMediaButton.IconKind.PAUSE, Color.WHITE).apply {
            layoutParams = FrameLayout.LayoutParams(dp(34f), dp(34f), Gravity.CENTER)
        }
        val playWrap = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(68f), dp(50f)).apply {
                marginStart = dp(24f)
                marginEnd = dp(24f)
            }
            setOnClickListener {
                ArchysMediaOverlayStore.dispatchAction("toggle")
            }
            addView(playBtn)
        }

        val nextWrap = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(56f), dp(46f))
            setOnClickListener {
                ArchysMediaOverlayStore.dispatchAction("next")
            }
            addView(
                VectorMediaButton(this@LockScreenPlayerActivity, VectorMediaButton.IconKind.NEXT, Color.WHITE).apply {
                    layoutParams = FrameLayout.LayoutParams(dp(28f), dp(28f), Gravity.CENTER)
                }
            )
        }

        transportRow.addView(prevWrap)
        transportRow.addView(playWrap)
        transportRow.addView(nextWrap)

        glassCard.addView(seekBar)
        glassCard.addView(timeRow)
        glassCard.addView(transportRow)
        topContentLayout.addView(glassCard)

        rootFrame.addView(
            topContentLayout,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )
    }

    private fun buildSeekBarDrawable(): LayerDrawable {
        val bg = GradientDrawable().apply {
            cornerRadius = dpF(99f)
            setColor(0x3DFFFFFF)
        }
        val fg = GradientDrawable().apply {
            cornerRadius = dpF(99f)
            setColor(Color.WHITE)
        }
        val clip = ClipDrawable(fg, Gravity.START, ClipDrawable.HORIZONTAL)
        return LayerDrawable(arrayOf(bg, clip)).apply {
            setId(0, android.R.id.background)
            setId(1, android.R.id.progress)
        }
    }

    private fun attachSwipeDownToDismiss(target: View) {
        var downY = 0f
        target.setOnTouchListener { _, ev ->
            when (ev.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downY = ev.rawY
                    false
                }
                MotionEvent.ACTION_UP -> {
                    val dy = ev.rawY - downY
                    if (dy > dp(52f)) {
                        finishSmoothly()
                        true
                    } else {
                        false
                    }
                }
                else -> false
            }
        }
    }

    private fun applyArtworkBitmap(bmp: Bitmap?) {
        artView.setArtworkBitmap(bmp)
    }

    private fun bindState(st: ArchysPlaybackState, rebuildLyricsIfNeeded: Boolean) {
        val accent = st.accentColor
        backdropScrim.background = GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            intArrayOf(
                Color.argb(184, 9, 12, 18),
                Color.argb(
                    172,
                    (Color.red(accent) * 0.18f).toInt(),
                    (Color.green(accent) * 0.18f).toInt(),
                    (Color.blue(accent) * 0.24f).toInt().coerceAtLeast(14)
                ),
                Color.argb(206, 7, 9, 14)
            )
        )

        glassCard.background = LiquidGlassCapsuleDrawable(
            cornerRadiusPx = dpF(26f),
            accentColor = accent,
            borderWidthPx = dpF(1.15f),
            expandedStyle = true
        )

        titleView.text = if (st.hasTrack && st.title.isNotBlank()) st.title else "Archys Music"
        artistView.text = if (st.hasTrack && st.artist.isNotBlank()) {
            st.artist
        } else {
            "Siap memutar"
        }
        eqView.update(st.isPlaying, Color.WHITE)
        playBtn.iconKind = if (st.isPlaying) VectorMediaButton.IconKind.PAUSE else VectorMediaButton.IconKind.PLAY
        playBtn.invalidate()

        val cachedArt = ArchysMediaOverlayStore.getCachedBitmap(st.artUrl)
        applyArtworkBitmap(cachedArt)

        val trackKey = "${st.trackId}|${st.lyrics.size}|${st.lyrics.firstOrNull()?.text ?: ""}"
        if (rebuildLyricsIfNeeded && (trackKey != lastTrackKey || renderedLyricsRef !== st.lyrics)) {
            lastTrackKey = trackKey
            renderedLyricsRef = st.lyrics
            rebuildLyricRows(st)
        }

        updateTimeAndLyricSpotlight(st)
    }

    private fun rebuildLyricRows(st: ArchysPlaybackState) {
        lyricsContainer.removeAllViews()
        lyricLineViews.clear()
        lastActiveLyricIdx = -2

        val lines = st.lyrics
        if (lines.isEmpty()) {
            lyricsScrollView.visibility = View.GONE
            emptyLyricsView.visibility = View.VISIBLE
            emptyLyricsView.text = if (st.hasTrack) {
                "Sedang memutar ${st.title}\n\nLirik lagu belum tersedia untuk trek ini"
            } else {
                "Putar lagu di Archys untuk membuka panel lirik di Lock Screen"
            }
            return
        }

        emptyLyricsView.visibility = View.GONE
        lyricsScrollView.visibility = View.VISIBLE

        for (i in lines.indices) {
            val line = lines[i]
            val tv = TextView(this).apply {
                text = if (!line.secondary.isNullOrBlank()) {
                    "${line.text}\n${line.secondary}"
                } else {
                    line.text
                }
                setTextColor(0x78FFFFFF)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 20.5f)
                typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
                setLineSpacing(dpF(2f), 1.06f)
                setPadding(dp(4f), dp(8f), dp(4f), dp(12f))
                val tMs = line.timeMs
                if (tMs != null) {
                    setOnClickListener {
                        ArchysMediaOverlayStore.dispatchAction("seek", tMs.toLong())
                    }
                }
            }
            lyricLineViews.add(tv)
            lyricsContainer.addView(tv)
        }
    }

    private fun updateTimeAndLyricSpotlight(st: ArchysPlaybackState) {
        val pos = st.currentPositionMs()
        val dur = st.durationMs.coerceAtLeast(0L)
        if (!isUserSeeking) {
            if (dur > 0L) {
                seekBar.progress = ((pos.toFloat() / dur.toFloat()) * 1000f).toInt().coerceIn(0, 1000)
                elapsedView.text = formatTime(pos)
                remainingView.text = "-${formatTime((dur - pos).coerceAtLeast(0L))}"
            } else {
                seekBar.progress = 0
                elapsedView.text = formatTime(pos)
                remainingView.text = "-0:00"
            }
        }

        val activeIdx = st.activeLyricIndex()
        if (activeIdx != lastActiveLyricIdx && lyricLineViews.isNotEmpty()) {
            lastActiveLyricIdx = activeIdx
            for (i in lyricLineViews.indices) {
                val tv = lyricLineViews[i]
                val isActive = (i == activeIdx)
                val isPast = activeIdx >= 0 && i < activeIdx
                tv.setTextColor(
                    when {
                        isActive -> Color.WHITE
                        isPast -> 0x5CFFFFFF.toInt()
                        else -> 0x82FFFFFF.toInt()
                    }
                )
                tv.setTextSize(TypedValue.COMPLEX_UNIT_SP, if (isActive) 24f else 20f)
                tv.setShadowLayer(if (isActive) 12f else 0f, 0f, 2f, 0x55FFFFFF)
            }
            if (activeIdx >= 0 && activeIdx < lyricLineViews.size) {
                val activeView = lyricLineViews[activeIdx]
                lyricsScrollView.post {
                    val scrollH = lyricsScrollView.height
                    if (scrollH > 0) {
                        val targetY = (activeView.top - scrollH * 0.34f).toInt().coerceAtLeast(0)
                        lyricsScrollView.smoothScrollTo(0, targetY)
                    }
                }
            }
        }
    }

    private fun formatTime(ms: Long): String {
        val sec = (ms / 1000L).coerceAtLeast(0L)
        val m = sec / 60L
        val s = sec % 60L
        return String.format(Locale.US, "%d:%02d", m, s)
    }

    private fun finishSmoothly() {
        if (isFinishing) return
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, android.R.anim.fade_out)
    }
}
