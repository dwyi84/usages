package com.melissasoft.aiusages.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.FolderOpen
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.OpenInFull
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.VerifiedUser
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.melissasoft.aiusages.model.BrandIcon
import com.melissasoft.aiusages.model.ProviderDescriptor
import com.melissasoft.aiusages.model.ProviderKeySpec
import com.melissasoft.aiusages.model.ServiceUsageSnapshot
import com.melissasoft.aiusages.model.TokenCostSnapshot
import com.melissasoft.aiusages.model.UsageTrendSummary
import com.melissasoft.aiusages.ui.theme.DS
import com.melissasoft.aiusages.ui.theme.GlassCard
import com.melissasoft.aiusages.ui.theme.GlassTile
import com.melissasoft.aiusages.ui.theme.SoftDivider
import com.melissasoft.aiusages.util.L10n
import java.util.Locale

@Composable
fun BrandIconView(
    brand: BrandIcon,
    size: Dp = 18.dp,
    modifier: Modifier = Modifier
) {
    val tint = if (brand.isMulticolor) null else (brand.tintColor ?: DS.textPrimary())
    Image(
        painter = painterResource(id = brand.drawableRes),
        contentDescription = brand.name,
        colorFilter = tint?.let { ColorFilter.tint(it) },
        modifier = modifier.size(size)
    )
}

@Composable
fun BrandIconChip(
    brand: BrandIcon,
    size: Dp = 18.dp,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .size(size + 10.dp)
            .clip(RoundedCornerShape(7.dp))
            .background(DS.chipFill())
            .border(0.6.dp, DS.subtleStroke(), RoundedCornerShape(7.dp)),
        contentAlignment = Alignment.Center
    ) {
        BrandIconView(brand = brand, size = size)
    }
}

@Composable
fun ProviderCardShell(
    providerId: String,
    brand: BrandIcon,
    title: String,
    canMoveUp: Boolean,
    canMoveDown: Boolean,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
    trailingHeader: @Composable () -> Unit,
    content: @Composable ColumnScope.() -> Unit
) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(DS.SpacingMd),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(
                        onClick = onMoveUp,
                        enabled = canMoveUp,
                        modifier = Modifier.size(22.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Filled.KeyboardArrowUp,
                            contentDescription = L10n.moveUp,
                            tint = if (canMoveUp) DS.textPrimary() else DS.textTertiary(),
                            modifier = Modifier.size(16.dp)
                        )
                    }
                    IconButton(
                        onClick = onMoveDown,
                        enabled = canMoveDown,
                        modifier = Modifier.size(22.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Filled.KeyboardArrowDown,
                            contentDescription = L10n.moveDown,
                            tint = if (canMoveDown) DS.textPrimary() else DS.textTertiary(),
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
                Spacer(Modifier.width(4.dp))
                BrandIconView(brand = brand, size = 18.dp)
                Spacer(Modifier.width(6.dp))
                Text(
                    text = title,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = DS.textPrimary(),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(Modifier.weight(1f))
                trailingHeader()
            }
            content()
        }
    }
}

@Composable
fun TwoPaneOrStacked(
    left: @Composable () -> Unit,
    right: @Composable () -> Unit
) {
    BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
        if (maxWidth >= 560.dp) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.Top
            ) {
                Box(modifier = Modifier.weight(1f)) { left() }
                Box(modifier = Modifier.weight(1f)) { right() }
            }
        } else {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                left()
                right()
            }
        }
    }
}

@Composable
fun WriteOnlyKeyEditor(
    promptLabel: String,
    placeholder: String,
    hasKey: Boolean,
    isEditing: Boolean,
    onStartEdit: () -> Unit,
    onCancelEdit: () -> Unit,
    onSaveKey: (String) -> Unit,
    onDeleteKey: () -> Unit,
    extraImportAction: (@Composable () -> Unit)? = null
) {
    var keyInput by remember(isEditing) { mutableStateOf("") }

    if (isEditing || !hasKey) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = promptLabel,
                    fontSize = 10.sp,
                    color = DS.textSecondary(),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
                if (hasKey) {
                    Text(
                        text = L10n.deleteKey,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Medium,
                        color = DS.BatteryRed,
                        modifier = Modifier
                            .clip(RoundedCornerShape(4.dp))
                            .clickable {
                                keyInput = ""
                                onDeleteKey()
                            }
                            .padding(horizontal = 4.dp, vertical = 2.dp)
                    )
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                OutlinedTextField(
                    value = keyInput,
                    onValueChange = { keyInput = it },
                    placeholder = { Text(placeholder, fontSize = 11.sp, maxLines = 1) },
                    singleLine = true,
                    visualTransformation = PasswordVisualTransformation(),
                    modifier = Modifier.weight(1f)
                )
                Button(
                    onClick = {
                        val cleaned = keyInput.trim()
                        if (cleaned.isNotEmpty()) {
                            onSaveKey(cleaned)
                            keyInput = ""
                        }
                    },
                    enabled = keyInput.trim().isNotEmpty(),
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 8.dp)
                ) {
                    Text(L10n.save, fontSize = 11.sp)
                }
                if (hasKey) {
                    IconButton(
                        onClick = {
                            keyInput = ""
                            onCancelEdit()
                        },
                        modifier = Modifier.size(28.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Filled.Close,
                            contentDescription = "Cancel",
                            tint = DS.textSecondary(),
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }
            if (extraImportAction != null) {
                extraImportAction()
            }
        }
    } else {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 2.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Filled.VerifiedUser,
                contentDescription = null,
                tint = DS.BatteryGreen,
                modifier = Modifier.size(13.dp)
            )
            Spacer(Modifier.width(5.dp))
            Text(
                text = L10n.keySavedSecurely,
                fontSize = 10.5.sp,
                fontWeight = FontWeight.Medium,
                color = DS.textSecondary()
            )
            Spacer(Modifier.weight(1f))
            if (extraImportAction != null) {
                extraImportAction()
                Spacer(Modifier.width(8.dp))
            }
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(4.dp))
                    .clickable(onClick = onStartEdit)
                    .padding(horizontal = 4.dp, vertical = 2.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Filled.Refresh,
                    contentDescription = null,
                    tint = DS.AccentBlue,
                    modifier = Modifier.size(11.dp)
                )
                Spacer(Modifier.width(3.dp))
                Text(
                    text = L10n.replaceKey,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium,
                    color = DS.AccentBlue
                )
            }
        }
    }
}

@Composable
fun OpenCodeSectionCard(
    snapshot: ServiceUsageSnapshot,
    selectedMetricKey: String,
    hasKey: Boolean,
    canMoveUp: Boolean,
    canMoveDown: Boolean,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
    onSelectMetric: (String) -> Unit,
    onSaveKey: (String) -> Unit,
    onDeleteKey: () -> Unit,
    onImportFile: () -> Unit,
    onOpenTrendDetail: (String, UsageTrendSummary) -> Unit
) {
    var isEditingKey by remember { mutableStateOf(false) }
    val windows = snapshot.openCodeWindows

    ProviderCardShell(
        providerId = "opencode",
        brand = BrandIcon.OPEN_CODE,
        title = L10n.openCodeTitle,
        canMoveUp = canMoveUp,
        canMoveDown = canMoveDown,
        onMoveUp = onMoveUp,
        onMoveDown = onMoveDown,
        trailingHeader = {
            Text(
                text = if (snapshot.isAvailable) "• ${windows.monthlyResetString}" else "• ${if (L10n.isKorean) "키 미설정" else "Key Not Set"}",
                fontSize = 10.sp,
                fontWeight = FontWeight.SemiBold,
                color = DS.textSecondary(),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    ) {
        TwoPaneOrStacked(
            left = {
                GlassTile(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.padding(10.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        if (snapshot.isAvailable) {
                            CleanProgressBar(
                                title = L10n.fiveHourWindow,
                                percent = windows.fiveHourRemainingPercent,
                                resetInfo = windows.fiveHourResetString,
                                isSelectedForIcon = selectedMetricKey == "opencode_5h",
                                onSelect = { onSelectMetric("opencode_5h") }
                            )
                            CleanProgressBar(
                                title = L10n.weekly,
                                percent = windows.weeklyRemainingPercent,
                                resetInfo = windows.weeklyResetString,
                                isSelectedForIcon = selectedMetricKey == "opencode_weekly",
                                onSelect = { onSelectMetric("opencode_weekly") }
                            )
                            CleanProgressBar(
                                title = L10n.monthly,
                                percent = windows.monthlyRemainingPercent,
                                resetInfo = windows.monthlyResetString,
                                isSelectedForIcon = selectedMetricKey == "opencode_monthly",
                                onSelect = { onSelectMetric("opencode_monthly") }
                            )
                            SoftDivider(alpha = 0.7f)
                        }

                        WriteOnlyKeyEditor(
                            promptLabel = L10n.enterOpenCodeKey,
                            placeholder = "oc_sk_...",
                            hasKey = hasKey,
                            isEditing = isEditingKey || !snapshot.isAvailable,
                            onStartEdit = { isEditingKey = true },
                            onCancelEdit = { isEditingKey = false },
                            onSaveKey = {
                                onSaveKey(it)
                                isEditingKey = false
                            },
                            onDeleteKey = {
                                onDeleteKey()
                                isEditingKey = false
                            },
                            extraImportAction = {
                                OutlinedButton(
                                    onClick = onImportFile,
                                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                                    modifier = Modifier.height(26.dp)
                                ) {
                                    Icon(
                                        imageVector = Icons.Filled.FolderOpen,
                                        contentDescription = null,
                                        modifier = Modifier.size(12.dp)
                                    )
                                    Spacer(Modifier.width(4.dp))
                                    Text(
                                        text = if (L10n.isKorean) "DB / auth.json 가져오기" else "Import DB / auth.json",
                                        fontSize = 9.5.sp
                                    )
                                }
                            }
                        )
                    }
                }
            },
            right = {
                ProviderTrendPanel(
                    title = L10n.openCodeTitle,
                    trend = snapshot.trendSummary,
                    onOpenDetail = { onOpenTrendDetail(L10n.openCodeTitle, snapshot.trendSummary) }
                )
            }
        )
    }
}

@Composable
fun GoogleAISectionCard(
    snapshot: ServiceUsageSnapshot,
    selectedMetricKey: String,
    billingDayOfMonth: Int,
    hasKey: Boolean,
    connectedEmail: String?,
    savedClientId: String?,
    hasSavedClientSecret: Boolean,
    isOAuthPending: Boolean,
    canMoveUp: Boolean,
    canMoveDown: Boolean,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
    onSelectMetric: (String) -> Unit,
    onSaveBillingDay: (Int) -> Unit,
    onSaveKey: (String) -> Unit,
    onDeleteKey: () -> Unit,
    onStartOAuthSignIn: (clientId: String, clientSecret: String?, useAndroidRedirect: Boolean) -> Unit,
    onSubmitManualOAuthCode: (String) -> Unit,
    onCancelOAuth: () -> Unit,
    onImportAuthOrClientJson: () -> Unit,
    onImportStepsDb: () -> Unit,
    onOpenTrendDetail: (String, UsageTrendSummary) -> Unit
) {
    var isEditingKey by remember { mutableStateOf(false) }
    var useOAuthTab by remember { mutableStateOf(!hasKey || !savedClientId.isNullOrBlank()) }
    var clientIdInput by remember(savedClientId) { mutableStateOf(savedClientId.orEmpty()) }
    var clientSecretInput by remember { mutableStateOf("") }
    var useAndroidRedirect by remember { mutableStateOf(false) }
    var manualOAuthInput by remember(isOAuthPending) { mutableStateOf("") }
    var isEditingBillingDay by remember { mutableStateOf(false) }
    var draftBillingDay by remember(billingDayOfMonth) {
        mutableIntStateOf(if (billingDayOfMonth in 1..31) billingDayOfMonth else 1)
    }
    var dayMenuExpanded by remember { mutableStateOf(false) }
    val groups = snapshot.googleGroups

    ProviderCardShell(
        providerId = "google_ai",
        brand = BrandIcon.GOOGLE_AI,
        title = L10n.googleAITitle,
        canMoveUp = canMoveUp,
        canMoveDown = canMoveDown,
        onMoveUp = onMoveUp,
        onMoveDown = onMoveDown,
        trailingHeader = {
            val headerNote = when {
                !connectedEmail.isNullOrBlank() -> "• $connectedEmail"
                billingDayOfMonth > 0 && groups.nextBillingDateString.isNotBlank() -> "• ${groups.nextBillingDateString}"
                else -> ""
            }
            if (headerNote.isNotBlank()) {
                Text(
                    text = headerNote,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = DS.textSecondary(),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    ) {
        if (!snapshot.statusMessage.isNullOrBlank()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(DS.BatteryAmber.copy(alpha = 0.14f))
                    .border(0.6.dp, DS.BatteryAmber.copy(alpha = 0.45f), RoundedCornerShape(8.dp))
                    .padding(horizontal = 10.dp, vertical = 7.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.Warning,
                    contentDescription = null,
                    tint = DS.BatteryAmber,
                    modifier = Modifier.size(14.dp)
                )
                Text(
                    text = snapshot.statusMessage,
                    fontSize = 10.5.sp,
                    color = DS.textPrimary(),
                    lineHeight = 14.sp
                )
            }
        }

        if (isEditingBillingDay) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(DS.AccentBlue.copy(alpha = 0.08f))
                    .padding(horizontal = 10.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = L10n.billingDayPrompt,
                    fontSize = 10.5.sp,
                    fontWeight = FontWeight.Medium,
                    color = DS.textPrimary()
                )
                Box {
                    OutlinedButton(
                        onClick = { dayMenuExpanded = true },
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 2.dp),
                        modifier = Modifier.height(28.dp)
                    ) {
                        Text("$draftBillingDay${L10n.dayUnit}", fontSize = 11.sp)
                    }
                    DropdownMenu(
                        expanded = dayMenuExpanded,
                        onDismissRequest = { dayMenuExpanded = false }
                    ) {
                        for (day in 1..31) {
                            DropdownMenuItem(
                                text = { Text("$day${L10n.dayUnit}") },
                                onClick = {
                                    draftBillingDay = day
                                    dayMenuExpanded = false
                                }
                            )
                        }
                    }
                }
                Button(
                    onClick = {
                        onSaveBillingDay(draftBillingDay)
                        isEditingBillingDay = false
                    },
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 2.dp),
                    modifier = Modifier.height(28.dp)
                ) {
                    Text(L10n.save, fontSize = 10.5.sp)
                }
                if (billingDayOfMonth > 0) {
                    TextButton(
                        onClick = {
                            onSaveBillingDay(0)
                            isEditingBillingDay = false
                        },
                        contentPadding = PaddingValues(horizontal = 6.dp, vertical = 2.dp),
                        modifier = Modifier.height(28.dp)
                    ) {
                        Text(L10n.reset, fontSize = 10.5.sp)
                    }
                }
                Spacer(Modifier.weight(1f))
                IconButton(
                    onClick = { isEditingBillingDay = false },
                    modifier = Modifier.size(22.dp)
                ) {
                    Icon(Icons.Filled.Close, contentDescription = "Close", modifier = Modifier.size(14.dp))
                }
            }
        }

        TwoPaneOrStacked(
            left = {
                GlassTile(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.padding(10.dp),
                        verticalArrangement = Arrangement.spacedBy(5.dp)
                    ) {
                        if (snapshot.isAvailable && (groups.hasAnyKnownQuota || snapshot.statusMessage == null)) {
                            Text(
                                text = L10n.fiveHourWindow,
                                fontSize = 9.5.sp,
                                fontWeight = FontWeight.Bold,
                                color = DS.textSecondary()
                            )
                            CleanProgressBar(
                                title = L10n.geminiModels,
                                percent = groups.geminiFiveHourRemainingPercent ?: 0.0,
                                resetInfo = groups.geminiFiveHourResetString,
                                isSelectedForIcon = selectedMetricKey == "google_gemini_5h",
                                onSelect = { onSelectMetric("google_gemini_5h") }
                            )
                            CleanProgressBar(
                                title = L10n.claudeAndGpt,
                                percent = groups.claudeFiveHourRemainingPercent ?: 0.0,
                                resetInfo = groups.claudeFiveHourResetString,
                                isSelectedForIcon = selectedMetricKey == "google_claude_5h",
                                onSelect = { onSelectMetric("google_claude_5h") }
                            )

                            SoftDivider(modifier = Modifier.padding(vertical = 2.dp), alpha = 0.7f)

                            Text(
                                text = L10n.weekly,
                                fontSize = 9.5.sp,
                                fontWeight = FontWeight.Bold,
                                color = DS.textSecondary()
                            )
                            CleanProgressBar(
                                title = L10n.geminiModels,
                                percent = groups.geminiWeeklyRemainingPercent ?: 0.0,
                                resetInfo = groups.geminiWeeklyResetString,
                                isSelectedForIcon = selectedMetricKey == "google_gemini_weekly",
                                onSelect = { onSelectMetric("google_gemini_weekly") }
                            )
                            CleanProgressBar(
                                title = L10n.claudeAndGpt,
                                percent = groups.claudeWeeklyRemainingPercent ?: 0.0,
                                resetInfo = groups.claudeWeeklyResetString,
                                isSelectedForIcon = selectedMetricKey == "google_claude_weekly",
                                onSelect = { onSelectMetric("google_claude_weekly") }
                            )
                            if (groups.argonWeeklyRemainingPercent != null) {
                                CleanProgressBar(
                                    title = L10n.geminiArgon,
                                    percent = groups.argonWeeklyRemainingPercent,
                                    resetInfo = groups.argonWeeklyResetString,
                                    isSelectedForIcon = selectedMetricKey == "google_argon_weekly",
                                    onSelect = { onSelectMetric("google_argon_weekly") }
                                )
                            }

                            SoftDivider(modifier = Modifier.padding(vertical = 2.dp), alpha = 0.7f)

                            // Monthly billing reset row
                            val monthlySelected = selectedMetricKey == "google_monthly"
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(DS.RadiusPill))
                                    .background(if (monthlySelected) DS.AccentBlue.copy(alpha = 0.1f) else Color.Transparent)
                                    .border(
                                        1.dp,
                                        if (monthlySelected) DS.AccentBlue.copy(alpha = 0.35f) else Color.Transparent,
                                        RoundedCornerShape(DS.RadiusPill)
                                    )
                                    .clickable { onSelectMetric("google_monthly") }
                                    .padding(horizontal = 6.dp, vertical = 5.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = if (monthlySelected) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked,
                                    contentDescription = null,
                                    tint = if (monthlySelected) DS.AccentBlue else DS.textTertiary(),
                                    modifier = Modifier.size(12.dp)
                                )
                                Spacer(Modifier.width(5.dp))
                                Icon(
                                    imageVector = Icons.Filled.CalendarMonth,
                                    contentDescription = null,
                                    tint = DS.textSecondary(),
                                    modifier = Modifier.size(12.dp)
                                )
                                Spacer(Modifier.width(5.dp))
                                Text(
                                    text = L10n.monthly,
                                    fontSize = 11.sp,
                                    fontWeight = if (monthlySelected) FontWeight.SemiBold else FontWeight.Medium,
                                    color = DS.textPrimary()
                                )
                                Spacer(Modifier.weight(1f))
                                Text(
                                    text = groups.nextBillingDateString.ifBlank { "-" },
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = DS.textPrimary(),
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                            }

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.End
                            ) {
                                Text(
                                    text = if (billingDayOfMonth > 0 && groups.nextBillingDateString.isNotBlank()) {
                                        if (L10n.isKorean) "리셋일 변경" else "Change Reset Day"
                                    } else {
                                        L10n.setBillingDay
                                    },
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = DS.AccentBlue,
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(4.dp))
                                        .clickable { isEditingBillingDay = !isEditingBillingDay }
                                        .padding(horizontal = 6.dp, vertical = 2.dp)
                                )
                            }

                            SoftDivider(alpha = 0.7f)
                        }

                        if (!hasKey || isEditingKey || isOAuthPending) {
                            // Mode selector: Google OAuth Browser Sign-In vs Auth Token / JSON
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(DS.RadiusPill))
                                    .background(DS.track())
                                    .padding(2.dp),
                                horizontalArrangement = Arrangement.spacedBy(2.dp)
                            ) {
                                listOf(
                                    true to (if (L10n.isKorean) "Google 계정 OAuth" else "Google OAuth"),
                                    false to (if (L10n.isKorean) "토큰 / JSON" else "Token / JSON")
                                ).forEach { (tabIsOAuth, label) ->
                                    val active = useOAuthTab == tabIsOAuth
                                    Box(
                                        modifier = Modifier
                                            .weight(1f)
                                            .clip(RoundedCornerShape(6.dp))
                                            .background(if (active) DS.AccentBlue else Color.Transparent)
                                            .clickable { useOAuthTab = tabIsOAuth }
                                            .padding(vertical = 5.dp),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Text(
                                            text = label,
                                            fontSize = 10.sp,
                                            fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium,
                                            color = if (active) Color.White else DS.textSecondary(),
                                            maxLines = 1
                                        )
                                    }
                                }
                            }

                            if (useOAuthTab) {
                                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Text(
                                            text = if (L10n.isKorean) "Google Cloud OAuth 클라이언트 설정" else "Google Cloud OAuth Client",
                                            fontSize = 10.sp,
                                            color = DS.textSecondary(),
                                            modifier = Modifier.weight(1f)
                                        )
                                        if (hasKey) {
                                            Text(
                                                text = L10n.deleteKey,
                                                fontSize = 10.sp,
                                                fontWeight = FontWeight.Medium,
                                                color = DS.BatteryRed,
                                                modifier = Modifier
                                                    .clip(RoundedCornerShape(4.dp))
                                                    .clickable {
                                                        onDeleteKey()
                                                        isEditingKey = false
                                                    }
                                                    .padding(horizontal = 4.dp, vertical = 2.dp)
                                            )
                                        }
                                        if (hasKey && !isOAuthPending) {
                                            Spacer(Modifier.width(4.dp))
                                            IconButton(
                                                onClick = { isEditingKey = false },
                                                modifier = Modifier.size(22.dp)
                                            ) {
                                                Icon(
                                                    imageVector = Icons.Filled.Close,
                                                    contentDescription = "Cancel",
                                                    tint = DS.textSecondary(),
                                                    modifier = Modifier.size(14.dp)
                                                )
                                            }
                                        }
                                    }

                                    OutlinedTextField(
                                        value = clientIdInput,
                                        onValueChange = { clientIdInput = it },
                                        placeholder = { Text("xxxx.apps.googleusercontent.com", fontSize = 10.5.sp, maxLines = 1) },
                                        singleLine = true,
                                        modifier = Modifier.fillMaxWidth()
                                    )
                                    OutlinedTextField(
                                        value = clientSecretInput,
                                        onValueChange = { clientSecretInput = it },
                                        placeholder = {
                                            Text(
                                                if (hasSavedClientSecret) {
                                                    if (L10n.isKorean) "Client Secret 저장됨 (변경 시 입력)" else "Client Secret saved (optional override)"
                                                } else {
                                                    if (L10n.isKorean) "Client Secret (Desktop JSON 시 선택)" else "Client Secret (optional)"
                                                },
                                                fontSize = 10.5.sp,
                                                maxLines = 1
                                            )
                                        },
                                        singleLine = true,
                                        visualTransformation = PasswordVisualTransformation(),
                                        modifier = Modifier.fillMaxWidth()
                                    )

                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                                    ) {
                                        Text(
                                            text = if (useAndroidRedirect) "Redirect: App URI" else "Redirect: 127.0.0.1",
                                            fontSize = 9.5.sp,
                                            color = DS.textSecondary(),
                                            modifier = Modifier
                                                .clip(RoundedCornerShape(4.dp))
                                                .background(DS.chipFill())
                                                .clickable { useAndroidRedirect = !useAndroidRedirect }
                                                .padding(horizontal = 6.dp, vertical = 3.dp)
                                        )
                                        Spacer(Modifier.weight(1f))
                                        OutlinedButton(
                                            onClick = onImportAuthOrClientJson,
                                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                                            modifier = Modifier.height(28.dp)
                                        ) {
                                            Icon(Icons.Filled.FolderOpen, contentDescription = null, modifier = Modifier.size(12.dp))
                                            Spacer(Modifier.width(4.dp))
                                            Text(L10n.importAuthOrClientJson, fontSize = 9.5.sp, maxLines = 1)
                                        }
                                    }

                                    Button(
                                        onClick = {
                                            onStartOAuthSignIn(
                                                clientIdInput,
                                                clientSecretInput.takeIf { it.isNotBlank() },
                                                useAndroidRedirect
                                            )
                                        },
                                        enabled = clientIdInput.trim().isNotEmpty() && !isOAuthPending,
                                        modifier = Modifier.fillMaxWidth(),
                                        contentPadding = PaddingValues(vertical = 8.dp)
                                    ) {
                                        Icon(Icons.Filled.AccountCircle, contentDescription = null, modifier = Modifier.size(15.dp))
                                        Spacer(Modifier.width(6.dp))
                                        Text(
                                            text = if (isOAuthPending) {
                                                if (L10n.isKorean) "브라우저 인증 대기 중..." else "Waiting for Google Sign-In..."
                                            } else {
                                                L10n.googleSignInButton
                                            },
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.SemiBold
                                        )
                                    }

                                    if (isOAuthPending) {
                                        Column(
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .clip(RoundedCornerShape(8.dp))
                                                .background(DS.AccentBlue.copy(alpha = 0.08f))
                                                .padding(8.dp),
                                            verticalArrangement = Arrangement.spacedBy(5.dp)
                                        ) {
                                            Text(
                                                text = if (L10n.isKorean) {
                                                    "자동 복귀가 안 되면 리디렉션된 주소(http://127.0.0.1...) 또는 code를 붙여넣으세요:"
                                                } else {
                                                    "If auto-return didn't trigger, paste the redirected URL or code:"
                                                },
                                                fontSize = 9.5.sp,
                                                color = DS.textSecondary()
                                            )
                                            Row(
                                                verticalAlignment = Alignment.CenterVertically,
                                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                                            ) {
                                                OutlinedTextField(
                                                    value = manualOAuthInput,
                                                    onValueChange = { manualOAuthInput = it },
                                                    placeholder = { Text("http://127.0.0.1... or 4/0A...", fontSize = 10.sp) },
                                                    singleLine = true,
                                                    modifier = Modifier.weight(1f)
                                                )
                                                Button(
                                                    onClick = { onSubmitManualOAuthCode(manualOAuthInput) },
                                                    enabled = manualOAuthInput.isNotBlank(),
                                                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp)
                                                ) {
                                                    Text(L10n.save, fontSize = 10.sp)
                                                }
                                                TextButton(
                                                    onClick = onCancelOAuth,
                                                    contentPadding = PaddingValues(horizontal = 4.dp, vertical = 2.dp)
                                                ) {
                                                    Text(if (L10n.isKorean) "취소" else "Cancel", fontSize = 10.sp)
                                                }
                                            }
                                        }
                                    }

                                    Text(
                                        text = if (L10n.isKorean) {
                                            "참고: cloudcode-pa는 Google 비공개 API라 일반 개인 GCP 클라이언트는 403이 발생할 수 있습니다. 기존 agy 인증 JSON이 있다면 파일 가져오기를 이용해 주세요."
                                        } else {
                                            "Note: cloudcode-pa is an internal Google API and may return 403 for personal GCP clients. Use Import Auth JSON if you have an agy token bundle."
                                        },
                                        fontSize = 9.sp,
                                        lineHeight = 12.sp,
                                        color = DS.textTertiary()
                                    )
                                }
                            } else {
                                WriteOnlyKeyEditor(
                                    promptLabel = L10n.enterGoogleToken,
                                    placeholder = "ya29... or {\"token\":...}",
                                    hasKey = hasKey,
                                    isEditing = true,
                                    onStartEdit = { isEditingKey = true },
                                    onCancelEdit = { isEditingKey = false },
                                    onSaveKey = {
                                        onSaveKey(it)
                                        isEditingKey = false
                                    },
                                    onDeleteKey = {
                                        onDeleteKey()
                                        isEditingKey = false
                                    },
                                    extraImportAction = {
                                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                            OutlinedButton(
                                                onClick = onImportAuthOrClientJson,
                                                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                                                modifier = Modifier.height(26.dp)
                                            ) {
                                                Icon(Icons.Filled.FolderOpen, contentDescription = null, modifier = Modifier.size(12.dp))
                                                Spacer(Modifier.width(4.dp))
                                                Text(L10n.importAuthOrClientJson, fontSize = 9.5.sp)
                                            }
                                            OutlinedButton(
                                                onClick = onImportStepsDb,
                                                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                                                modifier = Modifier.height(26.dp)
                                            ) {
                                                Icon(Icons.Filled.FolderOpen, contentDescription = null, modifier = Modifier.size(12.dp))
                                                Spacer(Modifier.width(4.dp))
                                                Text(
                                                    text = if (L10n.isKorean) "스텝 DB" else "Steps DB",
                                                    fontSize = 9.5.sp
                                                )
                                            }
                                        }
                                    }
                                )
                            }
                        } else {
                            WriteOnlyKeyEditor(
                                promptLabel = L10n.enterGoogleToken,
                                placeholder = "ya29... or {\"token\":...}",
                                hasKey = hasKey,
                                isEditing = false,
                                onStartEdit = { isEditingKey = true },
                                onCancelEdit = { isEditingKey = false },
                                onSaveKey = {
                                    onSaveKey(it)
                                    isEditingKey = false
                                },
                                onDeleteKey = {
                                    onDeleteKey()
                                    isEditingKey = false
                                },
                                extraImportAction = {
                                    OutlinedButton(
                                        onClick = onImportStepsDb,
                                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                                        modifier = Modifier.height(26.dp)
                                    ) {
                                        Icon(Icons.Filled.FolderOpen, contentDescription = null, modifier = Modifier.size(12.dp))
                                        Spacer(Modifier.width(4.dp))
                                        Text(
                                            text = if (L10n.isKorean) "스텝 DB 가져오기" else "Import Steps DB",
                                            fontSize = 9.5.sp
                                        )
                                    }
                                }
                            )
                        }
                    }
                }
            },
            right = {
                ProviderTrendPanel(
                    title = L10n.googleAITitle,
                    trend = snapshot.trendSummary,
                    onOpenDetail = { onOpenTrendDetail(L10n.googleAITitle, snapshot.trendSummary) }
                )
            }
        )
    }
}

@Composable
fun StatusBarIndicatorSettingCard(
    enabled: Boolean,
    hasPermission: Boolean,
    onToggle: (Boolean) -> Unit,
    onRequestPermission: () -> Unit
) {
    GlassTile(cornerRadius = DS.RadiusCard, modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable {
                    if (enabled && !hasPermission) {
                        onRequestPermission()
                    } else {
                        onToggle(!enabled)
                    }
                }
                .padding(horizontal = 12.dp, vertical = 9.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                imageVector = Icons.Filled.NotificationsActive,
                contentDescription = null,
                tint = if (enabled && hasPermission) DS.AccentBlue else DS.textSecondary(),
                modifier = Modifier.size(18.dp)
            )
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    text = L10n.statusBarIndicatorLabel,
                    fontSize = 11.5.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = DS.textPrimary()
                )
                Text(
                    text = when {
                        !enabled -> if (L10n.isKorean) "꺼짐 · 홈 화면 위젯만 표시" else "Off · Home Screen Widget only"
                        !hasPermission -> if (L10n.isKorean) "알림 권한 필요 · 탭하여 허용" else "Notification permission required · Tap to allow"
                        else -> if (L10n.isKorean) "켜짐 · 상단바 4칸 게이지 및 상시 축약 알림 표시" else "On · Status bar bars & compact ongoing shade"
                    },
                    fontSize = 10.sp,
                    color = if (enabled && !hasPermission) DS.BatteryAmber else DS.textSecondary()
                )
            }
            if (enabled && !hasPermission) {
                Button(
                    onClick = onRequestPermission,
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                    modifier = Modifier.height(28.dp)
                ) {
                    Text(if (L10n.isKorean) "권한 허용" else "Allow", fontSize = 10.sp)
                }
            } else {
                Switch(
                    checked = enabled,
                    onCheckedChange = onToggle,
                    modifier = Modifier.scale(0.8f),
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = Color.White,
                        checkedTrackColor = DS.AccentBlue
                    )
                )
            }
        }
    }
}

@Composable
fun OpenRouterSectionCard(
    snapshot: TokenCostSnapshot,
    hasKey: Boolean,
    canMoveUp: Boolean,
    canMoveDown: Boolean,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
    onSaveKey: (String) -> Unit,
    onDeleteKey: () -> Unit,
    onOpenTrendDetail: (String, UsageTrendSummary) -> Unit
) {
    var isEditingKey by remember { mutableStateOf(false) }

    ProviderCardShell(
        providerId = "openrouter",
        brand = BrandIcon.OPEN_ROUTER,
        title = L10n.openRouterTitle,
        canMoveUp = canMoveUp,
        canMoveDown = canMoveDown,
        onMoveUp = onMoveUp,
        onMoveDown = onMoveDown,
        trailingHeader = {
            val headerText = when {
                snapshot.isConnected -> String.format(Locale.US, "%s: $%.2f", L10n.balance, snapshot.balanceUSD)
                hasKey -> "• ${if (L10n.isKorean) "키 등록됨 · 확인 중" else "Key Saved · Checking"}"
                else -> "• ${if (L10n.isKorean) "키 미설정" else "Key Not Set"}"
            }
            Text(
                text = headerText,
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (snapshot.isConnected || hasKey) DS.AccentBlue else DS.textSecondary()
            )
        }
    ) {
        TwoPaneOrStacked(
            left = {
                GlassTile(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.padding(10.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text(
                                    text = L10n.balance,
                                    fontSize = 10.sp,
                                    color = DS.textSecondary()
                                )
                                Text(
                                    text = if (snapshot.isConnected) {
                                        String.format(Locale.US, "$%.2f", snapshot.balanceUSD)
                                    } else "—",
                                    fontSize = 18.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = DS.AccentBlue
                                )
                            }
                            Spacer(Modifier.weight(1f))
                            Text(
                                text = when {
                                    snapshot.isConnected -> if (L10n.isKorean) "✓ 연동됨" else "✓ Active"
                                    hasKey -> if (L10n.isKorean) "키 등록됨 · 확인 중" else "Key Saved · Checking"
                                    else -> if (L10n.isKorean) "키 등록 필요" else "Setup Required"
                                },
                                fontSize = 10.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = if (snapshot.isConnected) DS.BatteryGreen else DS.AccentBlue
                            )
                        }

                        SoftDivider(alpha = 0.7f)

                        WriteOnlyKeyEditor(
                            promptLabel = L10n.enterOpenRouterKey,
                            placeholder = "sk-or-...",
                            hasKey = hasKey,
                            isEditing = isEditingKey,
                            onStartEdit = { isEditingKey = true },
                            onCancelEdit = { isEditingKey = false },
                            onSaveKey = {
                                onSaveKey(it)
                                isEditingKey = false
                            },
                            onDeleteKey = {
                                onDeleteKey()
                                isEditingKey = false
                            }
                        )
                    }
                }
            },
            right = {
                ProviderTrendPanel(
                    title = L10n.openRouterTitle,
                    trend = snapshot.trendSummary,
                    onOpenDetail = { onOpenTrendDetail(L10n.openRouterTitle, snapshot.trendSummary) }
                )
            }
        )
    }
}

@Composable
fun KeyOnlyProviderCard(
    providerId: String,
    providerName: String,
    promptHint: String,
    placeholder: String,
    hasKey: Boolean,
    canMoveUp: Boolean,
    canMoveDown: Boolean,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
    onSaveKey: (String) -> Unit,
    onDeleteKey: () -> Unit,
    onOpenTrendDetail: (String, UsageTrendSummary) -> Unit
) {
    var isEditingKey by remember { mutableStateOf(false) }
    val brand = BrandIcon.fromProviderId(providerId)
    val trend = remember(hasKey) {
        UsageTrendSummary(
            dailyBars = List(30) { 0.05 },
            recentActivityLog = if (hasKey) {
                if (L10n.isKorean) "세션 연결됨 · 활동 대기" else "Session Connected · Ready"
            } else {
                if (L10n.isKorean) "API 연동 필요" else "Setup Required"
            }
        )
    }

    ProviderCardShell(
        providerId = providerId,
        brand = brand,
        title = providerName,
        canMoveUp = canMoveUp,
        canMoveDown = canMoveDown,
        onMoveUp = onMoveUp,
        onMoveDown = onMoveDown,
        trailingHeader = {
            Text(
                text = if (hasKey) "• ${if (L10n.isKorean) "연동됨" else "Active"}"
                else "• ${if (L10n.isKorean) "키 미설정" else "Key Not Set"}",
                fontSize = 10.sp,
                fontWeight = if (hasKey) FontWeight.SemiBold else FontWeight.Normal,
                color = if (hasKey) DS.BatteryGreen else DS.textSecondary()
            )
        }
    ) {
        TwoPaneOrStacked(
            left = {
                GlassTile(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.padding(10.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text(
                                    text = if (L10n.isKorean) "연동 상태" else "Status",
                                    fontSize = 10.sp,
                                    color = DS.textSecondary()
                                )
                                Text(
                                    text = if (hasKey) {
                                        if (L10n.isKorean) "API 키 연동" else "API Key Linked"
                                    } else {
                                        if (L10n.isKorean) "미설정" else "Not Linked"
                                    },
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (hasKey) DS.textPrimary() else DS.textSecondary()
                                )
                            }
                            Spacer(Modifier.weight(1f))
                            Text(
                                text = if (hasKey) {
                                    if (L10n.isKorean) "✓ 정상" else "✓ OK"
                                } else {
                                    if (L10n.isKorean) "키 등록 필요" else "Setup Required"
                                },
                                fontSize = 10.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = if (hasKey) DS.BatteryGreen else DS.AccentBlue
                            )
                        }

                        SoftDivider(alpha = 0.7f)

                        WriteOnlyKeyEditor(
                            promptLabel = promptHint,
                            placeholder = placeholder,
                            hasKey = hasKey,
                            isEditing = isEditingKey,
                            onStartEdit = { isEditingKey = true },
                            onCancelEdit = { isEditingKey = false },
                            onSaveKey = {
                                onSaveKey(it)
                                isEditingKey = false
                            },
                            onDeleteKey = {
                                onDeleteKey()
                                isEditingKey = false
                            }
                        )
                    }
                }
            },
            right = {
                ProviderTrendPanel(
                    title = providerName,
                    trend = trend,
                    onOpenDetail = { onOpenTrendDetail(providerName, trend) }
                )
            }
        )
    }
}

@Composable
fun CleanProgressBar(
    title: String,
    percent: Double,
    resetInfo: String,
    isSelectedForIcon: Boolean,
    onSelect: () -> Unit
) {
    val barColor = when {
        percent <= 15.0 -> DS.BatteryRed
        percent <= 35.0 -> DS.BatteryAmber
        else -> DS.BatteryGreen
    }
    val formattedPercent = if (percent % 1.0 == 0.0) {
        String.format(Locale.US, "%.0f%% %s", percent, L10n.remaining)
    } else {
        String.format(Locale.US, "%.2f%% %s", percent, L10n.remaining)
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(DS.RadiusPill))
            .background(if (isSelectedForIcon) DS.AccentBlue.copy(alpha = 0.1f) else Color.Transparent)
            .border(
                1.dp,
                if (isSelectedForIcon) DS.AccentBlue.copy(alpha = 0.35f) else Color.Transparent,
                RoundedCornerShape(DS.RadiusPill)
            )
            .clickable(onClick = onSelect)
            .padding(horizontal = 6.dp, vertical = 5.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = if (isSelectedForIcon) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked,
                contentDescription = null,
                tint = if (isSelectedForIcon) DS.AccentBlue else DS.textTertiary(),
                modifier = Modifier.size(12.dp)
            )
            Spacer(Modifier.width(5.dp))
            Text(
                text = title,
                fontSize = 11.sp,
                fontWeight = if (isSelectedForIcon) FontWeight.SemiBold else FontWeight.Medium,
                color = DS.textPrimary()
            )
            Spacer(Modifier.weight(1f))
            Text(
                text = formattedPercent,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                color = DS.textPrimary()
            )
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(DS.track())
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth((percent / 100.0).toFloat().coerceIn(0f, 1f))
                    .height(6.dp)
                    .clip(RoundedCornerShape(3.dp))
                    .background(barColor)
            )
        }

        if (resetInfo.isNotBlank() && resetInfo != "-") {
            Text(
                text = resetInfo,
                fontSize = 10.sp,
                color = DS.textSecondary()
            )
        }
    }
}

@Composable
fun ProviderTrendPanel(
    title: String,
    trend: UsageTrendSummary,
    onOpenDetail: () -> Unit
) {
    GlassTile(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(10.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(4.dp))
                    .clickable(onClick = onOpenDetail)
                    .padding(vertical = 2.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = L10n.usageTrend,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = DS.textPrimary()
                )
                Spacer(Modifier.width(4.dp))
                Icon(
                    imageVector = Icons.Filled.OpenInFull,
                    contentDescription = "Expand",
                    tint = DS.AccentBlue,
                    modifier = Modifier.size(11.dp)
                )
                Spacer(Modifier.weight(1f))
                MiniSparkline(bars = trend.dailyBars)
            }

            SoftDivider(alpha = 0.7f)

            TrendMetricRow(L10n.today, trend.todaySpendUSD, trend.todayTokens, trend)
            TrendMetricRow(L10n.yesterday, trend.yesterdaySpendUSD, trend.yesterdayTokens, trend)
            TrendMetricRow(L10n.last30Days, trend.last30DaysSpendUSD, trend.last30DaysTokens, trend)

            SoftDivider(alpha = 0.7f)

            TrendMetricRow(
                label = L10n.dailyAverage,
                spend = trend.dailyAvgSpendUSD,
                tokens = trend.dailyAvgTokens,
                trend = trend,
                secondary = true
            )

            if (trend.peakDateLabel.isNotBlank() && trend.peakTokens > 0) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = L10n.peakDay,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Medium,
                        color = DS.textSecondary()
                    )
                    Spacer(Modifier.weight(1f))
                    Text(
                        text = trend.peakDateLabel,
                        fontSize = 10.sp,
                        fontFamily = FontFamily.Monospace,
                        color = DS.textSecondary()
                    )
                    Spacer(Modifier.width(6.dp))
                    Text(
                        text = "${formatCompactNumber(trend.peakTokens)} ${trend.metricUnit.label}",
                        fontSize = 10.sp,
                        fontWeight = FontWeight.SemiBold,
                        fontFamily = FontFamily.Monospace,
                        color = DS.textPrimary()
                    )
                }
            }

            if (trend.recentActivityLog.isNotBlank()) {
                GlassTile(cornerRadius = DS.RadiusPill) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 8.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Filled.History,
                            contentDescription = null,
                            tint = DS.textSecondary(),
                            modifier = Modifier.size(11.dp)
                        )
                        Spacer(Modifier.width(5.dp))
                        Text(
                            text = trend.recentActivityLog,
                            fontSize = 10.sp,
                            color = DS.textSecondary(),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun TrendMetricRow(
    label: String,
    spend: Double,
    tokens: Int,
    trend: UsageTrendSummary,
    secondary: Boolean = false
) {
    val valueColor = if (secondary) DS.textSecondary() else DS.textPrimary()
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            fontSize = if (secondary) 10.sp else 10.5.sp,
            fontWeight = FontWeight.Medium,
            color = DS.textSecondary(),
            modifier = Modifier.weight(1f),
            maxLines = 1
        )
        Text(
            text = if (trend.costAvailable) String.format(Locale.US, "$%.2f", spend) else "—",
            fontSize = if (secondary) 10.sp else 11.sp,
            fontWeight = FontWeight.SemiBold,
            fontFamily = FontFamily.Monospace,
            color = valueColor,
            textAlign = TextAlign.End,
            modifier = Modifier.width(56.dp)
        )
        Text(
            text = "${formatCompactNumber(tokens)} ${trend.metricUnit.label}",
            fontSize = if (secondary) 10.sp else 11.sp,
            fontWeight = FontWeight.SemiBold,
            fontFamily = FontFamily.Monospace,
            color = valueColor,
            textAlign = TextAlign.End,
            modifier = Modifier.width(92.dp)
        )
    }
}

@Composable
fun MiniSparkline(bars: List<Double>) {
    Row(
        modifier = Modifier.height(14.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
        verticalAlignment = Alignment.Bottom
    ) {
        val count = minOf(30, bars.size)
        for (i in 0 until count) {
            val v = bars[i]
            if (v <= 0.001) {
                Box(
                    modifier = Modifier
                        .size(2.5.dp)
                        .clip(CircleShape)
                        .background(DS.AccentBlue.copy(alpha = 0.35f))
                )
            } else {
                Box(
                    modifier = Modifier
                        .width(2.5.dp)
                        .height((v * 14.0).coerceAtLeast(4.0).dp)
                        .clip(RoundedCornerShape(1.dp))
                        .background(DS.AccentBlue)
                )
            }
        }
    }
}

@Composable
fun ProviderManagementSection(
    providers: List<ProviderDescriptor>,
    expanded: Boolean,
    onToggleExpanded: () -> Unit,
    onToggleProvider: (String) -> Unit
) {
    val sorted = remember(providers) {
        providers.sortedBy { it.name.lowercase(Locale.ROOT) }
    }

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(6.dp))
                .clickable(onClick = onToggleExpanded)
                .padding(vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = L10n.providerMgmtTitle,
                fontSize = 11.5.sp,
                fontWeight = FontWeight.Bold,
                color = DS.textSecondary()
            )
            Spacer(Modifier.weight(1f))
            Icon(
                imageVector = if (expanded) Icons.Filled.KeyboardArrowUp else Icons.Filled.KeyboardArrowDown,
                contentDescription = null,
                tint = DS.AccentBlue,
                modifier = Modifier.size(16.dp)
            )
            Spacer(Modifier.width(2.dp))
            Text(
                text = if (expanded) L10n.collapse else L10n.manage,
                fontSize = 11.5.sp,
                fontWeight = FontWeight.Medium,
                color = DS.AccentBlue
            )
        }

        if (expanded) {
            GlassTile(cornerRadius = DS.RadiusCard, modifier = Modifier.fillMaxWidth()) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(10.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    BoxWithConstraints {
                        val cols = if (maxWidth >= 460.dp) 3 else 2
                        val gridRows = sorted.chunked(cols)
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            for (row in gridRows) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    for (provider in row) {
                                        ProviderGridTile(
                                            provider = provider,
                                            onToggle = { onToggleProvider(provider.id) },
                                            modifier = Modifier.weight(1f)
                                        )
                                    }
                                    repeat(cols - row.size) {
                                        Spacer(Modifier.weight(1f))
                                    }
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
private fun ProviderGridTile(
    provider: ProviderDescriptor,
    onToggle: () -> Unit,
    modifier: Modifier = Modifier
) {
    val brand = BrandIcon.fromProviderId(provider.id)
    val fill = if (provider.isEnabled) DS.AccentBlue.copy(alpha = 0.1f) else DS.tileFill()
    val stroke = if (provider.isEnabled) DS.AccentBlue.copy(alpha = 0.35f) else DS.subtleStroke()

    Row(
        modifier = modifier
            .clip(RoundedCornerShape(DS.RadiusTile))
            .background(fill)
            .border(0.8.dp, stroke, RoundedCornerShape(DS.RadiusTile))
            .clickable(onClick = onToggle)
            .padding(horizontal = 8.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box {
            BrandIconChip(brand = brand, size = 16.dp)
            if (provider.isDetected) {
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .size(7.dp)
                        .clip(CircleShape)
                        .background(DS.BatteryGreen)
                        .border(1.dp, DS.cardFill(), CircleShape)
                )
            }
        }
        Spacer(Modifier.width(6.dp))
        Text(
            text = if (provider.id == "opencode") "OpenCode" else provider.name,
            fontSize = 11.sp,
            fontWeight = if (provider.isEnabled) FontWeight.SemiBold else FontWeight.Normal,
            color = if (provider.isEnabled) DS.textPrimary() else DS.textSecondary(),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f)
        )
        Switch(
            checked = provider.isEnabled,
            onCheckedChange = { onToggle() },
            modifier = Modifier.scale(0.68f),
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = DS.AccentBlue
            )
        )
    }
}
