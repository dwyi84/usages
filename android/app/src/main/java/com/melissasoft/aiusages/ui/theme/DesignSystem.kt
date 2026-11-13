package com.melissasoft.aiusages.ui.theme

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

object DS {
    val SpacingXxs = 2.dp
    val SpacingXs = 4.dp
    val SpacingSm = 8.dp
    val SpacingMd = 12.dp
    val SpacingLg = 16.dp

    val RadiusPill = 8.dp
    val RadiusTile = 10.dp
    val RadiusCard = 14.dp

    val AccentBlue = Color(0xFF0A84FF)
    val BatteryGreen = Color(0xFF2ED159)
    val BatteryAmber = Color(0xFFFF9E0D)
    val BatteryRed = Color(0xFFFF453A)
    val RateLimitPurple = Color(0xFFAF52DE)
    val CoffeeYellow = Color(0xFFFFDD00)

    @Composable
    fun windowGradient(): Brush {
        return if (isSystemInDarkTheme()) {
            Brush.verticalGradient(listOf(Color(0xFF0F131A), Color(0xFF151B24)))
        } else {
            Brush.verticalGradient(listOf(Color(0xFFF2F5FA), Color(0xFFE9EEF6)))
        }
    }

    @Composable
    fun cardFill(): Color = if (isSystemInDarkTheme()) Color(0xCC1C222D) else Color(0xEBFFFFFF)

    @Composable
    fun tileFill(): Color = if (isSystemInDarkTheme()) Color(0x14FFFFFF) else Color(0x0D000000)

    @Composable
    fun chipFill(): Color = if (isSystemInDarkTheme()) Color(0x1FFFFFFF) else Color(0x14000000)

    @Composable
    fun stroke(): Color = if (isSystemInDarkTheme()) Color(0x26FFFFFF) else Color(0x22000000)

    @Composable
    fun subtleStroke(): Color = if (isSystemInDarkTheme()) Color(0x1AFFFFFF) else Color(0x18000000)

    @Composable
    fun track(): Color = if (isSystemInDarkTheme()) Color(0x26FFFFFF) else Color(0x1F000000)

    @Composable
    fun textPrimary(): Color = if (isSystemInDarkTheme()) Color(0xFFF3F6FA) else Color(0xFF111827)

    @Composable
    fun textSecondary(): Color = if (isSystemInDarkTheme()) Color(0xAAEDF2FA) else Color(0xAA1F2937)

    @Composable
    fun textTertiary(): Color = if (isSystemInDarkTheme()) Color(0x75EDF2FA) else Color(0x7A374151)
}

@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit
) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(DS.RadiusCard),
        color = DS.cardFill(),
        border = BorderStroke(0.8.dp, DS.stroke()),
        tonalElevation = 0.dp,
        shadowElevation = if (isSystemInDarkTheme()) 0.dp else 2.dp
    ) {
        Box(content = content)
    }
}

@Composable
fun GlassTile(
    modifier: Modifier = Modifier,
    fill: Color? = null,
    borderColor: Color? = null,
    cornerRadius: androidx.compose.ui.unit.Dp = DS.RadiusTile,
    content: @Composable BoxScope.() -> Unit
) {
    val shape = RoundedCornerShape(cornerRadius)
    Box(
        modifier = modifier
            .clip(shape)
            .background(fill ?: DS.tileFill())
            .border(0.75.dp, borderColor ?: DS.subtleStroke(), shape),
        content = content
    )
}

@Composable
fun SoftDivider(
    modifier: Modifier = Modifier,
    alpha: Float = 1f
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(0.75.dp)
            .background(DS.stroke().copy(alpha = DS.stroke().alpha * alpha))
    )
}

@Composable
fun AIUsagesTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    val scheme = if (dark) {
        darkColorScheme(
            primary = DS.AccentBlue,
            background = Color(0xFF0F131A),
            surface = Color(0xFF1C222D),
            onBackground = Color(0xFFF3F6FA),
            onSurface = Color(0xFFF3F6FA)
        )
    } else {
        lightColorScheme(
            primary = DS.AccentBlue,
            background = Color(0xFFF2F5FA),
            surface = Color(0xFFFFFFFF),
            onBackground = Color(0xFF111827),
            onSurface = Color(0xFF111827)
        )
    }
    MaterialTheme(
        colorScheme = scheme,
        content = content
    )
}
