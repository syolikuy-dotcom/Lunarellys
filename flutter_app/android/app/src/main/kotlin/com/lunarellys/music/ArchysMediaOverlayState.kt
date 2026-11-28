package com.lunarellys.music

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.drawable.Drawable
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.LruCache
import android.util.TypedValue
import android.view.View
import android.widget.ImageView
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.CopyOnWriteArraySet
import java.util.concurrent.Executors

data class LyricLineData(
    val timeMs: Int?,
    val text: String,
    val secondary: String? = null
)

data class ArchysPlaybackState(
    val enabled: Boolean = false,
    val alwaysVisible: Boolean = true,
    val systemOverlayEnabled: Boolean = true,
    val positionMode: String = "below", // "below" | "notch"
    val lockScreenLyricsEnabled: Boolean = false,
    val presetKey: String = "classic",
    val islandScale: Float = 1.0f,
    val islandYOffset: Float = 0f,
    val showLyrics: Boolean = true,
    val hasTrack: Boolean = false,
    val trackId: String = "",
    val title: String = "Archys",
    val artist: String = "",
    val artUrl: String = "",
    val isPlaying: Boolean = false,
    val positionMs: Long = 0L,
    val durationMs: Long = 0L,
    val syncedAtElapsedMs: Long = SystemClock.elapsedRealtime(),
    val lyricsOffsetMs: Int = 0,
    val accentColor: Int = 0xFF5DA7E8.toInt(),
    val lyrics: List<LyricLineData> = emptyList()
) {
    fun currentPositionMs(): Long {
        if (!hasTrack) return 0L
        val raw = if (isPlaying) {
            positionMs + (SystemClock.elapsedRealtime() - syncedAtElapsedMs).coerceAtLeast(0L)
        } else {
            positionMs
        }
        return if (durationMs > 0L) raw.coerceIn(0L, durationMs) else raw.coerceAtLeast(0L)
    }

    fun activeLyricIndex(): Int {
        if (lyrics.isEmpty()) return -1
        if (lyrics.none { it.timeMs != null }) return -1
        val posMs = currentPositionMs().toInt() + lyricsOffsetMs
        var active = 0
        for (i in lyrics.indices) {
            val t = lyrics[i].timeMs ?: continue
            if (t <= posMs) {
                active = i
            } else {
                break
            }
        }
        return active
    }
}

object ArchysMediaOverlayStore {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val bitmapCache = object : LruCache<String, Bitmap>(12) {}
    private val listeners = CopyOnWriteArraySet<(ArchysPlaybackState) -> Unit>()
    private val artListeners = CopyOnWriteArraySet<(String, Bitmap) -> Unit>()

    @Volatile
    var state: ArchysPlaybackState = ArchysPlaybackState()
        private set

    @Volatile
    var actionListener: ((String, Long?) -> Unit)? = null

    fun addStateListener(listener: (ArchysPlaybackState) -> Unit) {
        listeners.add(listener)
    }

    fun removeStateListener(listener: (ArchysPlaybackState) -> Unit) {
        listeners.remove(listener)
    }

    fun addArtListener(listener: (String, Bitmap) -> Unit) {
        artListeners.add(listener)
    }

    fun removeArtListener(listener: (String, Bitmap) -> Unit) {
        artListeners.remove(listener)
    }

    fun updateState(newState: ArchysPlaybackState) {
        state = newState
        if (newState.artUrl.isNotBlank()) {
            preloadArtwork(newState.artUrl)
        }
        mainHandler.post {
            for (l in listeners) {
                l.invoke(newState)
            }
        }
    }

    fun toggleOptimisticPlayPause() {
        val cur = state
        val pos = cur.currentPositionMs()
        updateState(
            cur.copy(
                isPlaying = !cur.isPlaying,
                positionMs = pos,
                syncedAtElapsedMs = SystemClock.elapsedRealtime()
            )
        )
    }

    fun seekOptimistic(positionMs: Long) {
        val cur = state
        val clamped = if (cur.durationMs > 0L) {
            positionMs.coerceIn(0L, cur.durationMs)
        } else {
            positionMs.coerceAtLeast(0L)
        }
        updateState(
            cur.copy(
                positionMs = clamped,
                syncedAtElapsedMs = SystemClock.elapsedRealtime()
            )
        )
    }

    fun dispatchAction(action: String, seekMs: Long? = null) {
        if (action == "toggle") {
            toggleOptimisticPlayPause()
        } else if (action == "seek" && seekMs != null) {
            seekOptimistic(seekMs)
        }
        actionListener?.invoke(action, seekMs)
    }

    fun getCachedBitmap(url: String): Bitmap? {
        if (url.isBlank()) return null
        return bitmapCache.get(url)
    }

    fun preloadArtwork(url: String) {
        if (url.isBlank()) return
        if (bitmapCache.get(url) != null) return
        executor.execute {
            if (bitmapCache.get(url) != null) return@execute
            try {
                val conn = (URL(url).openConnection() as HttpURLConnection).apply {
                    connectTimeout = 5000
                    readTimeout = 6000
                    doInput = true
                    instanceFollowRedirects = true
                }
                conn.connect()
                if (conn.responseCode in 200..299) {
                    conn.inputStream.use { stream ->
                        val decoded = BitmapFactory.decodeStream(stream)
                        if (decoded != null) {
                            val scaled = scaleBitmapIfNeeded(decoded, 420)
                            bitmapCache.put(url, scaled)
                            mainHandler.post {
                                for (l in artListeners) {
                                    l.invoke(url, scaled)
                                }
                            }
                        }
                    }
                }
                conn.disconnect()
            } catch (_: Exception) {
            }
        }
    }

    private fun scaleBitmapIfNeeded(src: Bitmap, maxEdge: Int): Bitmap {
        val w = src.width
        val h = src.height
        if (w <= maxEdge && h <= maxEdge) return src
        val ratio = maxEdge.toFloat() / maxOf(w, h).toFloat()
        val nw = (w * ratio).toInt().coerceAtLeast(1)
        val nh = (h * ratio).toInt().coerceAtLeast(1)
        val resized = Bitmap.createScaledBitmap(src, nw, nh, true)
        if (resized != src) {
            src.recycle()
        }
        return resized
    }
}

/**
 * Custom Canvas Liquid Glass background drawable featuring translucent dark obsidian
 * frosting, subtle chromatic album glow, darkened perimeter contrast edge, and
 * top-left directional Fresnel specular bevel highlight.
 */
class LiquidGlassCapsuleDrawable(
    private val cornerRadiusPx: Float,
    private val accentColor: Int,
    private val borderWidthPx: Float,
    private val expandedStyle: Boolean,
    private val presetKey: String = "classic"
) : Drawable() {

    private val rect = RectF()
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val outerDarkPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = borderWidthPx * 0.8f
        color = if (presetKey == "minimal_light") Color.argb(65, 15, 23, 42) else Color.argb(175, 0, 0, 0)
    }
    private val specularRimPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = borderWidthPx
    }

    override fun draw(canvas: Canvas) {
        val b = bounds
        if (b.isEmpty) return
        rect.set(b.left.toFloat(), b.top.toFloat(), b.right.toFloat(), b.bottom.toFloat())
        val radius = cornerRadiusPx.coerceAtMost(minOf(rect.width(), rect.height()) * 0.5f)

        val r = Color.red(accentColor)
        val g = Color.green(accentColor)
        val bl = Color.blue(accentColor)

        val colors = when (presetKey) {
            "minimal_light" -> intArrayOf(0xF4FFFFFF.toInt(), 0xEEF1F5F9.toInt(), 0xE6E2E8F0.toInt())
            "ios_blue" -> intArrayOf(0xE20F3268.toInt(), 0xDA0A2452.toInt(), 0xDF06183A.toInt())
            "aurora" -> intArrayOf(0xDC0B3532.toInt(), 0xD8211C52.toInt(), 0xDC101830.toInt())
            "glass" -> intArrayOf(0x9E162030.toInt(), 0x900D131F.toInt(), 0x98090D16.toInt())
            "dynamic" -> intArrayOf(
                Color.argb(226, (r * 0.34f).toInt(), (g * 0.34f).toInt(), (bl * 0.34f).toInt()),
                Color.argb(218, (r * 0.22f).toInt(), (g * 0.22f).toInt(), (bl * 0.22f).toInt()),
                Color.argb(224, (r * 0.14f).toInt(), (g * 0.14f).toInt(), (bl * 0.14f).toInt())
            )
            else -> intArrayOf(
                if (expandedStyle) 0xF4080A0F.toInt() else 0xF5040507.toInt(),
                if (expandedStyle) 0xF0040508.toInt() else 0xF2020304.toInt(),
                0xF4000000.toInt()
            )
        }

        fillPaint.shader = LinearGradient(
            rect.left,
            rect.top,
            rect.left,
            rect.bottom,
            colors,
            floatArrayOf(0f, 0.52f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawRoundRect(rect, radius, radius, fillPaint)

        // Soft chromatic refraction on top-left corner
        val glowR = maxOf(rect.width(), rect.height()) * 0.65f
        val accentAlpha = when (presetKey) {
            "minimal_light" -> Color.argb(28, r, g, bl)
            "aurora" -> Color.argb(72, 94, 234, 212)
            "ios_blue" -> Color.argb(74, 59, 130, 246)
            else -> Color.argb(if (expandedStyle) 56 else 44, r, g, bl)
        }
        glowPaint.shader = RadialGradient(
            rect.left + rect.width() * 0.18f,
            rect.top + rect.height() * 0.15f,
            glowR.coerceAtLeast(1f),
            intArrayOf(accentAlpha, Color.TRANSPARENT),
            floatArrayOf(0f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawRoundRect(rect, radius, radius, glowPaint)

        // Outer contrast stroke
        val outerRect = RectF(rect).apply { inset(borderWidthPx * 0.4f, borderWidthPx * 0.4f) }
        val outerRadius = (radius - borderWidthPx * 0.4f).coerceAtLeast(1f)
        canvas.drawRoundRect(outerRect, outerRadius, outerRadius, outerDarkPaint)

        // Inner Fresnel specular bevel highlight
        val innerRect = RectF(rect).apply { inset(borderWidthPx * 1.05f, borderWidthPx * 1.05f) }
        val innerRadius = (radius - borderWidthPx * 1.05f).coerceAtLeast(1f)
        val accentRim = when (presetKey) {
            "minimal_light" -> Color.argb(95, r, g, bl)
            "aurora" -> Color.argb(145, 94, 234, 212)
            "ios_blue" -> Color.argb(145, 96, 165, 250)
            else -> Color.argb(if (expandedStyle) 110 else 86, r, g, bl)
        }
        specularRimPaint.shader = LinearGradient(
            innerRect.left,
            innerRect.top,
            innerRect.right,
            innerRect.bottom,
            intArrayOf(
                if (presetKey == "minimal_light") 0xFFFFFFFF.toInt() else 0xC8FFFFFF.toInt(),
                accentRim,
                if (presetKey == "minimal_light") 0x380F172A else 0x24FFFFFF,
                0x70FFFFFF
            ),
            floatArrayOf(0f, 0.32f, 0.68f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawRoundRect(innerRect, innerRadius, innerRadius, specularRimPaint)
    }

    override fun setAlpha(alpha: Int) {
        fillPaint.alpha = alpha
    }

    override fun setColorFilter(colorFilter: android.graphics.ColorFilter?) {
        fillPaint.colorFilter = colorFilter
    }

    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = android.graphics.PixelFormat.TRANSLUCENT
}

/**
 * Rounded album art ImageView with clean placeholder glyph when artwork is loading.
 */
class RoundedArtworkView(
    context: Context,
    private val cornerRadiusPx: Float
) : ImageView(context) {
    private val clipPath = Path()
    private val rect = RectF()
    private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0x26FFFFFF
    }
    private val wavePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xDDF8FAFC.toInt()
        strokeCap = Paint.Cap.ROUND
    }
    var hasImage: Boolean = false
        private set

    init {
        scaleType = ScaleType.CENTER_CROP
    }

    fun setArtworkBitmap(bitmap: Bitmap?) {
        hasImage = bitmap != null
        setImageBitmap(bitmap)
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        rect.set(0f, 0f, width.toFloat(), height.toFloat())
        clipPath.reset()
        clipPath.addRoundRect(rect, cornerRadiusPx, cornerRadiusPx, Path.Direction.CW)
        canvas.save()
        canvas.clipPath(clipPath)
        if (hasImage && drawable != null) {
            super.onDraw(canvas)
        } else {
            canvas.drawRect(rect, bgPaint)
            // Minimal harmonic waveform placeholder matching iOS audio placeholder
            val bars = floatArrayOf(0.28f, 0.48f, 0.72f, 0.42f, 0.80f, 0.56f, 0.34f)
            val totalW = rect.width() * 0.58f
            val step = totalW / bars.size
            val startX = (rect.width() - totalW) * 0.5f + step * 0.5f
            val cy = rect.centerY()
            wavePaint.strokeWidth = (step * 0.46f).coerceAtLeast(2f)
            for (i in bars.indices) {
                val halfH = rect.height() * 0.34f * bars[i]
                val x = startX + i * step
                canvas.drawLine(x, cy - halfH, x, cy + halfH, wavePaint)
            }
        }
        canvas.restore()
    }
}

/**
 * Smooth animated 4-bar equalizer drawn natively on Canvas.
 */
class NativeEqualizerView(context: Context) : View(context) {
    private var playing: Boolean = false
    private var barColor: Int = 0xFF60A5FA.toInt()
    private var phase: Float = 0f
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        strokeCap = Paint.Cap.ROUND
    }
    private val rect = RectF()
    private val tickRunnable = object : Runnable {
        override fun run() {
            if (!playing || !isAttachedToWindow) return
            phase += 0.22f
            invalidate()
            postDelayed(this, 42L)
        }
    }

    fun update(isPlaying: Boolean, color: Int) {
        val wasPlaying = playing
        playing = isPlaying
        barColor = color
        if (playing && !wasPlaying) {
            removeCallbacks(tickRunnable)
            post(tickRunnable)
        } else if (!playing) {
            removeCallbacks(tickRunnable)
        }
        invalidate()
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        if (playing) {
            removeCallbacks(tickRunnable)
            post(tickRunnable)
        }
    }

    override fun onDetachedFromWindow() {
        removeCallbacks(tickRunnable)
        super.onDetachedFromWindow()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width.toFloat()
        val h = height.toFloat()
        if (w <= 0f || h <= 0f) return

        paint.color = barColor
        val barCount = 4
        val gap = w * 0.11f
        val barW = ((w - gap * (barCount - 1)) / barCount).coerceAtLeast(2f)
        val freqs = floatArrayOf(1.0f, 1.45f, 1.15f, 1.65f)
        val offsets = floatArrayOf(0.0f, 1.3f, 2.6f, 0.7f)

        for (i in 0 until barCount) {
            val ratio = if (playing) {
                val s = kotlin.math.sin((phase * freqs[i] + offsets[i]).toDouble()).toFloat()
                0.28f + ((s + 1f) * 0.5f) * 0.72f
            } else {
                0.24f + (i % 2) * 0.14f
            }
            val barH = (h * ratio).coerceAtLeast(barW)
            val left = i * (barW + gap)
            val top = (h - barH) * 0.5f
            rect.set(left, top, left + barW, top + barH)
            canvas.drawRoundRect(rect, barW * 0.5f, barW * 0.5f, paint)
        }
    }
}

/**
 * Custom Canvas vector icons for crisp Apple-style media controls (no ugly unicode text!).
 */
class VectorMediaButton(
    context: Context,
    var iconKind: IconKind,
    var tintColor: Int = Color.WHITE
) : View(context) {

    enum class IconKind { PREV, PLAY, PAUSE, NEXT, COLLAPSE, OPEN, CLOSE }

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }
    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val path = Path()
    private val rect = RectF()

    private fun dp(v: Float): Float =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, resources.displayMetrics)

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width.toFloat()
        val h = height.toFloat()
        if (w <= 0f || h <= 0f) return
        val cx = w * 0.5f
        val cy = h * 0.5f
        val unit = minOf(w, h) * 0.44f

        paint.color = tintColor
        strokePaint.color = tintColor
        strokePaint.strokeWidth = dp(2.1f)

        when (iconKind) {
            IconKind.PLAY -> {
                val r = unit * 0.85f
                val left = cx - r * 0.62f
                val right = cx + r * 0.92f
                path.reset()
                path.moveTo(left, cy - r * 0.88f)
                path.lineTo(right, cy)
                path.lineTo(left, cy + r * 0.88f)
                path.close()
                canvas.drawPath(path, paint)
            }
            IconKind.PAUSE -> {
                val barW = unit * 0.42f
                val barH = unit * 1.48f
                val gap = unit * 0.36f
                val r = barW * 0.38f
                rect.set(cx - gap * 0.5f - barW, cy - barH * 0.5f, cx - gap * 0.5f, cy + barH * 0.5f)
                canvas.drawRoundRect(rect, r, r, paint)
                rect.set(cx + gap * 0.5f, cy - barH * 0.5f, cx + gap * 0.5f + barW, cy + barH * 0.5f)
                canvas.drawRoundRect(rect, r, r, paint)
            }
            IconKind.PREV -> {
                // Double left-pointing rounded triangles
                val triW = unit * 0.78f
                val triH = unit * 1.15f
                drawTriangle(canvas, cx - triW * 0.05f, cy, -triW, triH)
                drawTriangle(canvas, cx + triW * 0.92f, cy, -triW, triH)
            }
            IconKind.NEXT -> {
                val triW = unit * 0.78f
                val triH = unit * 1.15f
                drawTriangle(canvas, cx - triW * 0.92f, cy, triW, triH)
                drawTriangle(canvas, cx + triW * 0.05f, cy, triW, triH)
            }
            IconKind.COLLAPSE -> {
                val hw = unit * 0.72f
                val hh = unit * 0.38f
                path.reset()
                path.moveTo(cx - hw, cy + hh)
                path.lineTo(cx, cy - hh)
                path.lineTo(cx + hw, cy + hh)
                canvas.drawPath(path, strokePaint)
            }
            IconKind.OPEN -> {
                val r = unit * 0.62f
                path.reset()
                path.moveTo(cx - r * 0.6f, cy + r * 0.6f)
                path.lineTo(cx + r * 0.65f, cy - r * 0.65f)
                path.moveTo(cx - r * 0.1f, cy - r * 0.65f)
                path.lineTo(cx + r * 0.65f, cy - r * 0.65f)
                path.lineTo(cx + r * 0.65f, cy + r * 0.1f)
                canvas.drawPath(path, strokePaint)
            }
            IconKind.CLOSE -> {
                val r = unit * 0.56f
                path.reset()
                path.moveTo(cx - r, cy - r)
                path.lineTo(cx + r, cy + r)
                path.moveTo(cx + r, cy - r)
                path.lineTo(cx - r, cy + r)
                canvas.drawPath(path, strokePaint)
            }
        }
    }

    private fun drawTriangle(canvas: Canvas, tipOrBaseX: Float, cy: Float, widthSigned: Float, height: Float) {
        val hh = height * 0.5f
        path.reset()
        path.moveTo(tipOrBaseX, cy - hh)
        path.lineTo(tipOrBaseX + widthSigned, cy)
        path.lineTo(tipOrBaseX, cy + hh)
        path.close()
        canvas.drawPath(path, paint)
    }
}
