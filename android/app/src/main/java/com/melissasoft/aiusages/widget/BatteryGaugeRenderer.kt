package com.melissasoft.aiusages.widget

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import com.melissasoft.aiusages.model.GaugeStatus
import kotlin.math.ceil

object BatteryGaugeRenderer {
    data class GaugeItem(
        val percent: Double,
        val status: GaugeStatus
    )

    fun activeSegmentCount(percent: Double, segmentCount: Int = 4): Int {
        if (percent <= 0.0) return 0
        return ceil((percent / 100.0) * segmentCount).toInt().coerceIn(1, segmentCount)
    }

    fun resolveColorArgb(percent: Double, status: GaugeStatus): Int {
        return when {
            status == GaugeStatus.RATE_LIMITED -> 0xFFAF52DE.toInt()
            percent <= 15.0 -> 0xFFFF453A.toInt()
            percent <= 35.0 -> 0xFFFF9E0D.toInt()
            else -> 0xFF2ED159.toInt()
        }
    }

    data class BarGeometry(
        val canvasWidthPx: Float,
        val canvasHeightPx: Float,
        val barWidthPx: Float,
        val barSpacingPx: Float,
        val startXPx: Float,
        val topYPx: Float,
        val bottomYPx: Float,
        val segHeightPx: Float,
        val segGapPx: Float
    )

    /**
     * Computes square 24dp layout metrics for Android's monochrome status bar icon (`smallIcon`)
     * so 1-3 bars stay centered inside the system safe zone regardless of OEM density.
     */
    fun computeStatusBarLayout(barCount: Int, hasResetDot: Boolean, density: Float = 3f): BarGeometry {
        val count = barCount.coerceIn(1, 3)
        val sizePx = 24f * density
        val segHeight = 3.1f * density
        val segGap = 1.15f * density
        val totalBarHeight = (4 * segHeight) + (3 * segGap)
        val topY = if (hasResetDot) 2.5f * density else (sizePx - totalBarHeight) / 2f
        val bottomY = topY + totalBarHeight
        val (barW, barGap) = when (count) {
            1 -> 7.0f * density to 0f
            2 -> 6.0f * density to 3.0f * density
            else -> 4.8f * density to 2.2f * density
        }
        val totalW = count * barW + (count - 1) * barGap
        val startX = (sizePx - totalW) / 2f
        return BarGeometry(
            canvasWidthPx = sizePx,
            canvasHeightPx = sizePx,
            barWidthPx = barW,
            barSpacingPx = barGap,
            startXPx = startX,
            topYPx = topY,
            bottomYPx = bottomY,
            segHeightPx = segHeight,
            segGapPx = segGap
        )
    }

    /**
     * Renders a crisp 24dp square monochrome alpha-mask Bitmap for Android Notification smallIcon
     * so the top Status Bar indicator displays the signature 4-segment bars matching macOS.
     */
    fun renderStatusBarIconBitmap(
        items: List<GaugeItem>,
        daysUntilReset: Int,
        density: Float = 3f
    ): Bitmap {
        val displayItems = if (items.isEmpty()) {
            listOf(GaugeItem(0.0, GaugeStatus.UNKNOWN))
        } else {
            items.take(3)
        }
        val showDot = daysUntilReset in 0..3 && items.isNotEmpty()
        val layout = computeStatusBarLayout(displayItems.size, showDot, density)
        val bitmap = Bitmap.createBitmap(
            layout.canvasWidthPx.toInt().coerceAtLeast(24),
            layout.canvasHeightPx.toInt().coerceAtLeast(24),
            Bitmap.Config.ARGB_8888
        )
        val canvas = Canvas(bitmap)
        val activePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = 0xFFFFFFFF.toInt()
        }
        val inactivePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = 0x52FFFFFF
        }
        val cornerRadius = 0.9f * density

        displayItems.forEachIndexed { idx, item ->
            val barX = layout.startXPx + idx * (layout.barWidthPx + layout.barSpacingPx)
            val activeSegs = activeSegmentCount(item.percent, 4)
            for (i in 0 until 4) {
                val segBottom = layout.bottomYPx - i * (layout.segHeightPx + layout.segGapPx)
                val segTop = segBottom - layout.segHeightPx
                val rect = RectF(barX, segTop, barX + layout.barWidthPx, segBottom)
                canvas.drawRoundRect(
                    rect,
                    cornerRadius,
                    cornerRadius,
                    if (i < activeSegs) activePaint else inactivePaint
                )
            }
        }

        if (showDot) {
            val dotRadius = 1.15f * density
            val dotCx = layout.canvasWidthPx / 2f
            val dotCy = (layout.bottomYPx + 2.2f * density).coerceAtMost(layout.canvasHeightPx - dotRadius - 0.5f * density)
            canvas.drawCircle(dotCx, dotCy, dotRadius, activePaint)
        }

        return bitmap
    }

    /**
     * Renders 1-3 vertical 4-segment battery gauge bars into a crisp Bitmap
     * matching macOS BatteryGaugeRenderer.swift.
     */
    fun renderDynamicBarsBitmap(
        items: List<GaugeItem>,
        daysUntilReset: Int,
        density: Float = 3f,
        lightInactiveTint: Boolean = true
    ): Bitmap {
        val canvasHeightPx = (24f * density).toInt().coerceAtLeast(24)
        val segmentCount = 4
        val segmentWidth = 4.5f * density
        val segmentHeight = 3.0f * density
        val segmentGap = 1.2f * density
        val barSpacing = 3.0f * density

        val displayItems = if (items.isEmpty()) {
            listOf(GaugeItem(0.0, GaugeStatus.UNKNOWN))
        } else {
            items.take(3)
        }
        val barCount = displayItems.size
        val totalBarHeight = (segmentCount * segmentHeight) + ((segmentCount - 1) * segmentGap)
        val totalWidth = (barCount * segmentWidth) + ((barCount - 1).coerceAtLeast(0) * barSpacing)
        val startX = 2f * density
        val bitmapWidthPx = (totalWidth + startX * 2f).toInt().coerceAtLeast(24)

        val bitmap = Bitmap.createBitmap(bitmapWidthPx, canvasHeightPx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val topY = (canvasHeightPx - totalBarHeight) / 2f
        val bottomY = topY + totalBarHeight

        val activePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
        val inactivePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = if (lightInactiveTint) 0x38FFFFFF else 0x2E000000
        }
        val cornerRadius = 1.0f * density

        displayItems.forEachIndexed { idx, item ->
            val barX = startX + idx * (segmentWidth + barSpacing)
            val activeSegs = activeSegmentCount(item.percent, segmentCount)
            activePaint.color = resolveColorArgb(item.percent, item.status)

            for (i in 0 until segmentCount) {
                val segBottom = bottomY - i * (segmentHeight + segmentGap)
                val segTop = segBottom - segmentHeight
                val rect = RectF(barX, segTop, barX + segmentWidth, segBottom)
                canvas.drawRoundRect(
                    rect,
                    cornerRadius,
                    cornerRadius,
                    if (i < activeSegs) activePaint else inactivePaint
                )
            }
        }

        if (daysUntilReset in 0..3) {
            val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.FILL
                color = 0xFFFF9E0D.toInt()
            }
            val dotRadius = 1.2f * density
            val dotCx = startX + totalWidth / 2f
            val dotCy = (bottomY + 2.4f * density).coerceAtMost(canvasHeightPx - dotRadius)
            canvas.drawCircle(dotCx, dotCy, dotRadius, dotPaint)
        }

        return bitmap
    }
}
