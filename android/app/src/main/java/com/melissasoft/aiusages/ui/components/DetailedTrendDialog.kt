package com.melissasoft.aiusages.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.melissasoft.aiusages.model.UsageTrendSummary
import com.melissasoft.aiusages.ui.theme.DS
import com.melissasoft.aiusages.ui.theme.GlassCard
import com.melissasoft.aiusages.ui.theme.GlassTile
import com.melissasoft.aiusages.ui.theme.SoftDivider
import com.melissasoft.aiusages.util.L10n
import java.util.Locale
import kotlin.math.max

@Composable
fun DetailedTrendDialog(
    title: String,
    summary: UsageTrendSummary,
    onDismiss: () -> Unit
) {
    val dailyPoints = summary.dailyPoints
    val maxTokens = max(dailyPoints.maxOfOrNull { it.tokens } ?: 0, 1)
    val peakPoint = dailyPoints.maxByOrNull { it.tokens }
    var selectedIdx by remember { mutableStateOf<Int?>(null) }
    var chartWidthPx by remember { mutableStateOf(1f) }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        GlassCard(
            modifier = Modifier
                .fillMaxWidth(0.94f)
                .padding(vertical = 16.dp)
        ) {
            Column(
                modifier = Modifier.padding(DS.SpacingLg),
                verticalArrangement = Arrangement.spacedBy(DS.SpacingMd)
            ) {
                // Header
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Filled.BarChart,
                        contentDescription = null,
                        tint = DS.AccentBlue,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(Modifier.width(6.dp))
                    Text(
                        text = "$title ${L10n.detailedTrendTitle}",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                        color = DS.textPrimary(),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f, fill = false)
                    )
                    Spacer(Modifier.width(4.dp))
                    Text(
                        text = "(${L10n.last30Days})",
                        fontSize = 11.sp,
                        color = DS.textSecondary()
                    )
                    Spacer(Modifier.weight(1f))
                    IconButton(onClick = onDismiss, modifier = Modifier.size(28.dp)) {
                        Icon(
                            imageVector = Icons.Filled.Close,
                            contentDescription = "Close",
                            tint = DS.textSecondary(),
                            modifier = Modifier.size(18.dp)
                        )
                    }
                }

                // 4 Summary Metrics Cards (2x2 on narrow mobile)
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        MetricCard(
                            title = summary.metricUnit.title,
                            value = formatCompactNumber(summary.last30DaysTokens),
                            valueColor = DS.textPrimary(),
                            modifier = Modifier.weight(1f)
                        )
                        MetricCard(
                            title = if (L10n.isKorean) "총 환산비용" else "Total Cost",
                            value = if (summary.costAvailable) {
                                String.format(Locale.US, "$%.2f", summary.last30DaysSpendUSD)
                            } else "—",
                            valueColor = DS.BatteryGreen,
                            modifier = Modifier.weight(1f)
                        )
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        MetricCard(
                            title = L10n.dailyAverage,
                            value = formatCompactNumber(
                                summary.last30DaysTokens / max(dailyPoints.size, 1)
                            ),
                            valueColor = DS.AccentBlue,
                            modifier = Modifier.weight(1f)
                        )
                        MetricCard(
                            title = L10n.peakDay,
                            value = if (peakPoint != null && peakPoint.tokens > 0) {
                                "${peakPoint.dateLabel}: ${formatCompactNumber(peakPoint.tokens)}"
                            } else "-",
                            valueColor = DS.textPrimary(),
                            modifier = Modifier.weight(1f)
                        )
                    }
                }

                // Interactive Inspection Banner
                GlassTile(
                    cornerRadius = DS.RadiusPill,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(34.dp)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 10.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        val pt = selectedIdx?.let { idx -> dailyPoints.getOrNull(idx) }
                        if (pt != null) {
                            Box(
                                modifier = Modifier
                                    .size(6.dp)
                                    .clip(CircleShape)
                                    .background(DS.AccentBlue)
                            )
                            Spacer(Modifier.width(6.dp))
                            Text(
                                text = "${pt.dateString} (${pt.dateLabel})",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = DS.textPrimary(),
                                maxLines = 1
                            )
                            Text(
                                text = "  •  ",
                                fontSize = 10.sp,
                                color = DS.textSecondary()
                            )
                            Text(
                                text = "${formatCompactNumber(pt.tokens)} ${summary.metricUnit.label}",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.SemiBold,
                                fontFamily = FontFamily.Monospace,
                                color = DS.AccentBlue
                            )
                            if (summary.costAvailable) {
                                Text(
                                    text = "  •  ",
                                    fontSize = 10.sp,
                                    color = DS.textSecondary()
                                )
                                Text(
                                    text = String.format(Locale.US, "$%.2f", pt.spendUSD),
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    fontFamily = FontFamily.Monospace,
                                    color = DS.BatteryGreen
                                )
                            }
                        } else {
                            Icon(
                                imageVector = Icons.Filled.TouchApp,
                                contentDescription = null,
                                tint = DS.textSecondary(),
                                modifier = Modifier.size(13.dp)
                            )
                            Spacer(Modifier.width(5.dp))
                            Text(
                                text = L10n.trendChartTip,
                                fontSize = 10.5.sp,
                                color = DS.textSecondary(),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                }

                // Detailed Chart Area with Y-Axis & X-Axis
                GlassTile(
                    cornerRadius = 10.dp,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(
                        modifier = Modifier.padding(DS.SpacingMd),
                        verticalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(130.dp),
                            verticalAlignment = Alignment.Bottom
                        ) {
                            // Y-Axis Labels
                            Column(
                                modifier = Modifier
                                    .width(44.dp)
                                    .fillMaxHeight(),
                                verticalArrangement = Arrangement.SpaceBetween,
                                horizontalAlignment = Alignment.End
                            ) {
                                Text(
                                    text = formatCompactNumber(maxTokens),
                                    fontSize = 9.5.sp,
                                    fontFamily = FontFamily.Monospace,
                                    color = DS.textSecondary()
                                )
                                Text(
                                    text = formatCompactNumber(maxTokens / 2),
                                    fontSize = 9.5.sp,
                                    fontFamily = FontFamily.Monospace,
                                    color = DS.textSecondary()
                                )
                                Text(
                                    text = "0",
                                    fontSize = 9.5.sp,
                                    fontFamily = FontFamily.Monospace,
                                    color = DS.textSecondary()
                                )
                            }

                            Spacer(Modifier.width(8.dp))

                            // Plot Area with Touch Scrubbing
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .fillMaxHeight()
                                    .onSizeChanged { chartWidthPx = it.width.toFloat().coerceAtLeast(1f) }
                                    .pointerInput(dailyPoints.size) {
                                        detectTapGestures { offset ->
                                            if (dailyPoints.isNotEmpty()) {
                                                val idx = ((offset.x / chartWidthPx) * dailyPoints.size)
                                                    .toInt()
                                                    .coerceIn(0, dailyPoints.lastIndex)
                                                selectedIdx = idx
                                            }
                                        }
                                    }
                                    .pointerInput(dailyPoints.size) {
                                        detectHorizontalDragGestures { change, _ ->
                                            change.consume()
                                            if (dailyPoints.isNotEmpty()) {
                                                val idx = ((change.position.x / chartWidthPx) * dailyPoints.size)
                                                    .toInt()
                                                    .coerceIn(0, dailyPoints.lastIndex)
                                                selectedIdx = idx
                                            }
                                        }
                                    }
                            ) {
                                Column(
                                    modifier = Modifier.fillMaxHeight(),
                                    verticalArrangement = Arrangement.SpaceBetween
                                ) {
                                    SoftDivider(alpha = 0.5f)
                                    SoftDivider(alpha = 0.25f)
                                    SoftDivider(alpha = 0.6f)
                                }

                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .fillMaxHeight(),
                                    verticalAlignment = Alignment.Bottom
                                ) {
                                    dailyPoints.forEachIndexed { idx, pt ->
                                        val isSelected = selectedIdx == idx
                                        val fraction = (pt.tokens.toFloat() / maxTokens.toFloat()).coerceIn(0f, 1f)
                                        Box(
                                            modifier = Modifier
                                                .weight(1f)
                                                .fillMaxHeight()
                                                .padding(horizontal = 1.5.dp),
                                            contentAlignment = Alignment.BottomCenter
                                        ) {
                                            if (pt.tokens > 0) {
                                                Box(
                                                    modifier = Modifier
                                                        .fillMaxWidth()
                                                        .height((fraction * 124f).coerceAtLeast(4f).dp)
                                                        .clip(RoundedCornerShape(2.dp))
                                                        .background(if (isSelected) DS.BatteryAmber else DS.AccentBlue)
                                                )
                                            } else {
                                                Box(
                                                    modifier = Modifier
                                                        .padding(bottom = 1.dp)
                                                        .size(3.5.dp)
                                                        .clip(CircleShape)
                                                        .background(
                                                            if (isSelected) DS.BatteryAmber
                                                            else DS.AccentBlue.copy(alpha = 0.35f)
                                                        )
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // X-Axis Date Ticks
                        Row(modifier = Modifier.fillMaxWidth()) {
                            Spacer(Modifier.width(52.dp))
                            if (dailyPoints.isNotEmpty()) {
                                Row(
                                    modifier = Modifier.weight(1f),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text(
                                        text = dailyPoints[0].dateLabel,
                                        fontSize = 9.5.sp,
                                        fontFamily = FontFamily.Monospace,
                                        color = DS.textSecondary()
                                    )
                                    if (dailyPoints.size > 7) {
                                        Text(
                                            text = dailyPoints[7].dateLabel,
                                            fontSize = 9.5.sp,
                                            fontFamily = FontFamily.Monospace,
                                            color = DS.textSecondary()
                                        )
                                    }
                                    if (dailyPoints.size > 14) {
                                        Text(
                                            text = dailyPoints[14].dateLabel,
                                            fontSize = 9.5.sp,
                                            fontFamily = FontFamily.Monospace,
                                            color = DS.textSecondary()
                                        )
                                    }
                                    if (dailyPoints.size > 21) {
                                        Text(
                                            text = dailyPoints[21].dateLabel,
                                            fontSize = 9.5.sp,
                                            fontFamily = FontFamily.Monospace,
                                            color = DS.textSecondary()
                                        )
                                    }
                                    Text(
                                        text = dailyPoints.last().dateLabel,
                                        fontSize = 9.5.sp,
                                        fontWeight = FontWeight.Bold,
                                        fontFamily = FontFamily.Monospace,
                                        color = DS.textPrimary()
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun MetricCard(
    title: String,
    value: String,
    valueColor: Color,
    modifier: Modifier = Modifier
) {
    GlassTile(modifier = modifier) {
        Column(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                text = title,
                fontSize = 10.sp,
                color = DS.textSecondary(),
                maxLines = 1
            )
            Text(
                text = value,
                fontSize = 12.5.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                color = valueColor,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

fun formatCompactNumber(count: Int): String = when {
    count >= 1_000_000_000 -> String.format(Locale.US, "%.1fB", count / 1_000_000_000.0)
    count >= 1_000_000 -> String.format(Locale.US, "%.1fM", count / 1_000_000.0)
    count >= 1_000 -> String.format(Locale.US, "%.1fK", count / 1_000.0)
    else -> count.toString()
}
