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
