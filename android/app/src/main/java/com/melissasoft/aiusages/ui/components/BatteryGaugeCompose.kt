package com.melissasoft.aiusages.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.melissasoft.aiusages.model.GaugeStatus
import com.melissasoft.aiusages.widget.BatteryGaugeRenderer

@Composable
fun BatteryGaugeStrip(
    items: List<BatteryGaugeRenderer.GaugeItem>,
    daysUntilReset: Int,
    modifier: Modifier = Modifier
) {
    val displayItems = if (items.isEmpty()) {
        listOf(BatteryGaugeRenderer.GaugeItem(0.0, GaugeStatus.UNKNOWN))
    } else {
        items.take(3)
    }
    val barCount = displayItems.size
    val segWidthDp = 5.dp
    val barGapDp = 3.dp
    val totalWidthDp = segWidthDp * barCount + barGapDp * (barCount - 1).coerceAtLeast(0) + 4.dp
    val inactiveColor = if (isSystemInDarkTheme()) Color(0x38FFFFFF) else Color(0x28000000)

    Canvas(
        modifier = modifier
            .width(totalWidthDp)
            .height(24.dp)
    ) {
        val segmentCount = 4
        val segmentWidth = 5.dp.toPx()
        val segmentHeight = 3.2.dp.toPx()
        val segmentGap = 1.2.dp.toPx()
        val barSpacing = 3.dp.toPx()
        val totalBarHeight = segmentCount * segmentHeight + (segmentCount - 1) * segmentGap
        val startX = 2.dp.toPx()
        val topY = (size.height - totalBarHeight) / 2f
        val bottomY = topY + totalBarHeight
        val radius = CornerRadius(1.dp.toPx(), 1.dp.toPx())

        displayItems.forEachIndexed { idx, item ->
            val barX = startX + idx * (segmentWidth + barSpacing)
            val activeSegs = BatteryGaugeRenderer.activeSegmentCount(item.percent, segmentCount)
            val activeColor = Color(BatteryGaugeRenderer.resolveColorArgb(item.percent, item.status))

            for (i in 0 until segmentCount) {
                val segBottom = bottomY - i * (segmentHeight + segmentGap)
                val segTop = segBottom - segmentHeight
                drawRoundRect(
                    color = if (i < activeSegs) activeColor else inactiveColor,
                    topLeft = Offset(barX, segTop),
                    size = Size(segmentWidth, segmentHeight),
                    cornerRadius = radius
                )
            }
        }

        if (daysUntilReset in 0..3) {
            val totalBarsWidth = barCount * segmentWidth + (barCount - 1).coerceAtLeast(0) * barSpacing
            drawCircle(
                color = Color(0xFFFF9E0D),
                radius = 1.4.dp.toPx(),
                center = Offset(
                    x = startX + totalBarsWidth / 2f,
                    y = (bottomY + 2.4.dp.toPx()).coerceAtMost(size.height - 1.5.dp.toPx())
                )
            )
        }
    }
}
