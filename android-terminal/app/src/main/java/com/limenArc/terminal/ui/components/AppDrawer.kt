package com.limenArc.terminal.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.limenArc.terminal.ui.theme.*

sealed class AppDestination(val route: String, val label: String, val icon: ImageVector, val color: androidx.compose.ui.graphics.Color) {
    data object Terminal    : AppDestination("terminal",    "Terminal",     Icons.Default.Terminal,       TerminalGreen)
    data object FileBrowser : AppDestination("files",       "File Browser", Icons.Default.Folder,         TerminalYellow)
    data object Packages    : AppDestination("packages",    "Packages",     Icons.Default.Inventory2,     TerminalMagenta)
    data object Settings    : AppDestination("settings",    "Settings",     Icons.Default.Settings,       TerminalCyan)
}

val allDestinations = listOf(
    AppDestination.Terminal,
    AppDestination.FileBrowser,
    AppDestination.Packages,
    AppDestination.Settings,
)

@Composable
fun AppDrawer(
    currentRoute: String,
    onNavigate: (AppDestination) -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    ModalDrawerSheet(
        modifier = modifier,
        drawerContainerColor = TerminalSurface,
    ) {
        // Header
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(TerminalBackground)
                .padding(24.dp),
        ) {
            Column {
                Icon(
                    Icons.Default.Terminal,
                    contentDescription = null,
                    tint = TerminalGreen,
                    modifier = Modifier.size(40.dp),
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    "LimenArc",
                    color = TerminalGreen,
                    fontSize = 20.sp,
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    "Terminal",
                    color = TerminalTextDim,
                    fontSize = 14.sp,
                    fontFamily = FontFamily.Monospace,
                )
            }
        }

        HorizontalDivider(color = TerminalBorder)

        Spacer(Modifier.height(8.dp))

        allDestinations.forEach { dest ->
            val isSelected = currentRoute == dest.route
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 2.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(if (isSelected) dest.color.copy(alpha = 0.12f) else androidx.compose.ui.graphics.Color.Transparent)
                    .clickable { onNavigate(dest); onClose() }
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    dest.icon,
                    contentDescription = dest.label,
                    tint = if (isSelected) dest.color else TerminalTextDim,
                    modifier = Modifier.size(22.dp),
                )
                Spacer(Modifier.width(16.dp))
                Text(
                    dest.label,
                    color = if (isSelected) dest.color else TerminalText,
                    fontSize = 15.sp,
                    fontWeight = if (isSelected) FontWeight.Medium else FontWeight.Normal,
                )
                if (isSelected) {
                    Spacer(Modifier.weight(1f))
                    Box(
                        modifier = Modifier
                            .size(6.dp)
                            .clip(RoundedCornerShape(50))
                            .background(dest.color),
                    )
                }
            }
        }

        Spacer(Modifier.weight(1f))

        HorizontalDivider(color = TerminalBorder, modifier = Modifier.padding(horizontal = 12.dp))
        Spacer(Modifier.height(8.dp))

        Text(
            "v1.0.0  •  LimenArc",
            color = TerminalTextDim,
            fontSize = 11.sp,
            fontFamily = FontFamily.Monospace,
            modifier = Modifier.padding(start = 28.dp, bottom = 16.dp),
        )
    }
}
