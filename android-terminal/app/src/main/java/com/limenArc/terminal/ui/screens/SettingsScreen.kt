package com.limenArc.terminal.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.limenArc.terminal.ui.theme.*

data class SettingsState(
    val fontSize: Int = 13,
    val fontFamily: String = "Monospace",
    val terminalBell: Boolean = true,
    val keepScreenOn: Boolean = false,
    val fullscreen: Boolean = false,
    val cursorBlink: Boolean = true,
    val scrollback: Int = 3000,
    val colorScheme: String = "Matrix Green",
    val startupCommand: String = "",
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(onOpenDrawer: () -> Unit) {
    var state by remember { mutableStateOf(SettingsState()) }

    Scaffold(
        containerColor = TerminalBackground,
        topBar = {
            TopAppBar(
                title = { Text("Settings", color = TerminalCyan) },
                navigationIcon = {
                    IconButton(onClick = onOpenDrawer) {
                        Icon(Icons.Default.Menu, "Menu", tint = TerminalText)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = TerminalSurface),
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(vertical = 12.dp),
        ) {
            item { SectionHeader("Appearance") }

            item {
                SettingsCard {
                    SliderSetting(
                        icon = Icons.Default.TextFields,
                        label = "Font Size",
                        value = state.fontSize.toFloat(),
                        valueRange = 8f..24f,
                        displayValue = "${state.fontSize}sp",
                        onValueChange = { state = state.copy(fontSize = it.toInt()) },
                    )
                }
            }

            item {
                SettingsCard {
                    DropdownSetting(
                        icon = Icons.Default.Palette,
                        label = "Color Scheme",
                        value = state.colorScheme,
                        options = listOf("Matrix Green", "Dracula", "Solarized Dark", "Monokai", "One Dark", "Gruvbox"),
                        onSelect = { state = state.copy(colorScheme = it) },
                    )
                    HorizontalDivider(color = TerminalBorder, thickness = 0.5.dp, modifier = Modifier.padding(start = 48.dp))
                    DropdownSetting(
                        icon = Icons.Default.FontDownload,
                        label = "Font Family",
                        value = state.fontFamily,
                        options = listOf("Monospace", "Courier New", "Source Code Pro", "JetBrains Mono", "Fira Code"),
                        onSelect = { state = state.copy(fontFamily = it) },
                    )
                }
            }

            item { SectionHeader("Terminal") }

            item {
                SettingsCard {
                    SwitchSetting(Icons.Default.NotificationsActive, "Terminal Bell", state.terminalBell) {
                        state = state.copy(terminalBell = it)
                    }
                    HorizontalDivider(color = TerminalBorder, thickness = 0.5.dp, modifier = Modifier.padding(start = 48.dp))
                    SwitchSetting(Icons.Default.BlinkingCursor, "Cursor Blink", state.cursorBlink) {
                        state = state.copy(cursorBlink = it)
                    }
                    HorizontalDivider(color = TerminalBorder, thickness = 0.5.dp, modifier = Modifier.padding(start = 48.dp))
                    SliderSetting(
                        icon = Icons.Default.History,
                        label = "Scrollback Lines",
                        value = state.scrollback.toFloat(),
                        valueRange = 500f..10000f,
                        displayValue = "${state.scrollback}",
                        onValueChange = { state = state.copy(scrollback = it.toInt()) },
                    )
                }
            }

            item { SectionHeader("Display") }

            item {
                SettingsCard {
                    SwitchSetting(Icons.Default.ScreenLockLandscape, "Keep Screen On", state.keepScreenOn) {
                        state = state.copy(keepScreenOn = it)
                    }
                    HorizontalDivider(color = TerminalBorder, thickness = 0.5.dp, modifier = Modifier.padding(start = 48.dp))
                    SwitchSetting(Icons.Default.Fullscreen, "Fullscreen Mode", state.fullscreen) {
                        state = state.copy(fullscreen = it)
                    }
                }
            }

            item { SectionHeader("Session") }

            item {
                SettingsCard {
                    TextFieldSetting(
                        icon = Icons.Default.Terminal,
                        label = "Startup Command",
                        value = state.startupCommand,
                        placeholder = "e.g. bash -l",
                        onValueChange = { state = state.copy(startupCommand = it) },
                    )
                }
            }

            item { SectionHeader("About") }

            item {
                SettingsCard {
                    InfoRow(Icons.Default.Info, "Version", "1.0.0")
                    HorizontalDivider(color = TerminalBorder, thickness = 0.5.dp, modifier = Modifier.padding(start = 48.dp))
                    InfoRow(Icons.Default.Code, "Build", "LimenArc Terminal")
                }
            }
        }
    }
}

@Composable
private fun SectionHeader(text: String) {
    Text(
        text.uppercase(),
        color = TerminalCyan,
        fontSize = 11.sp,
        fontFamily = FontFamily.Monospace,
        modifier = Modifier.padding(start = 4.dp, top = 8.dp, bottom = 4.dp),
    )
}

@Composable
private fun SettingsCard(content: @Composable ColumnScope.() -> Unit) {
    Surface(
        color = TerminalSurface,
        shape = RoundedCornerShape(10.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(content = content)
    }
}

@Composable
private fun SwitchSetting(icon: ImageVector, label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().clickable { onChange(!checked) }.padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, tint = TerminalTextDim, modifier = Modifier.size(22.dp))
        Spacer(Modifier.width(12.dp))
        Text(label, color = TerminalText, fontSize = 14.sp, modifier = Modifier.weight(1f))
        Switch(checked = checked, onCheckedChange = onChange, colors = SwitchDefaults.colors(checkedThumbColor = TerminalBackground, checkedTrackColor = TerminalGreen, uncheckedTrackColor = TerminalSurfaceAlt))
    }
}

@Composable
private fun SliderSetting(icon: ImageVector, label: String, value: Float, valueRange: ClosedFloatingPointRange<Float>, displayValue: String, onValueChange: (Float) -> Unit) {
    Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, null, tint = TerminalTextDim, modifier = Modifier.size(22.dp))
            Spacer(Modifier.width(12.dp))
            Text(label, color = TerminalText, fontSize = 14.sp, modifier = Modifier.weight(1f))
            Text(displayValue, color = TerminalGreen, fontSize = 13.sp, fontFamily = FontFamily.Monospace)
        }
        Slider(value = value, onValueChange = onValueChange, valueRange = valueRange, modifier = Modifier.padding(start = 34.dp), colors = SliderDefaults.colors(thumbColor = TerminalGreen, activeTrackColor = TerminalGreen))
    }
}

@Composable
private fun DropdownSetting(icon: ImageVector, label: String, value: String, options: List<String>, onSelect: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Row(
        modifier = Modifier.fillMaxWidth().clickable { expanded = true }.padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, tint = TerminalTextDim, modifier = Modifier.size(22.dp))
        Spacer(Modifier.width(12.dp))
        Text(label, color = TerminalText, fontSize = 14.sp, modifier = Modifier.weight(1f))
        Text(value, color = TerminalGreen, fontSize = 13.sp, fontFamily = FontFamily.Monospace)
        Spacer(Modifier.width(4.dp))
        Icon(Icons.Default.ArrowDropDown, null, tint = TerminalTextDim, modifier = Modifier.size(20.dp))
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            containerColor = TerminalSurfaceAlt,
        ) {
            options.forEach { opt ->
                DropdownMenuItem(
                    text = { Text(opt, color = if (opt == value) TerminalGreen else TerminalText, fontSize = 13.sp) },
                    onClick = { onSelect(opt); expanded = false },
                )
            }
        }
    }
}

@Composable
private fun TextFieldSetting(icon: ImageVector, label: String, value: String, placeholder: String, onValueChange: (String) -> Unit) {
    Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(bottom = 6.dp)) {
            Icon(icon, null, tint = TerminalTextDim, modifier = Modifier.size(22.dp))
            Spacer(Modifier.width(12.dp))
            Text(label, color = TerminalText, fontSize = 14.sp)
        }
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.fillMaxWidth().padding(start = 34.dp),
            placeholder = { Text(placeholder, color = TerminalTextDim, fontSize = 13.sp, fontFamily = FontFamily.Monospace) },
            colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = TerminalCyan, unfocusedBorderColor = TerminalBorder, focusedTextColor = TerminalText, unfocusedTextColor = TerminalText, cursorColor = TerminalCyan),
            textStyle = androidx.compose.ui.text.TextStyle(fontFamily = FontFamily.Monospace, fontSize = 13.sp, color = TerminalText),
            singleLine = true,
        )
    }
}

@Composable
private fun InfoRow(icon: ImageVector, label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, tint = TerminalTextDim, modifier = Modifier.size(22.dp))
        Spacer(Modifier.width(12.dp))
        Text(label, color = TerminalText, fontSize = 14.sp, modifier = Modifier.weight(1f))
        Text(value, color = TerminalTextDim, fontSize = 13.sp, fontFamily = FontFamily.Monospace)
    }
}
