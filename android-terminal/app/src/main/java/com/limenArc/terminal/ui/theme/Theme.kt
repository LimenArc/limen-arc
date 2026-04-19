package com.limenArc.terminal.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

private val DarkColorScheme = darkColorScheme(
    primary          = TerminalGreen,
    onPrimary        = TerminalBackground,
    primaryContainer = TerminalSurfaceAlt,
    secondary        = TerminalBlue,
    onSecondary      = TerminalBackground,
    background       = TerminalBackground,
    onBackground     = TerminalText,
    surface          = TerminalSurface,
    onSurface        = TerminalText,
    surfaceVariant   = TerminalSurfaceAlt,
    onSurfaceVariant = TerminalTextDim,
    outline          = TerminalBorder,
    error            = TerminalRed,
    onError          = TerminalBackground,
)

val TerminalTypography = androidx.compose.material3.Typography(
    bodyLarge  = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 14.sp, fontWeight = FontWeight.Normal),
    bodyMedium = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 13.sp),
    bodySmall  = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 12.sp),
    labelLarge = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 13.sp, fontWeight = FontWeight.Medium),
)

@Composable
fun LimenArcTerminalTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        typography  = TerminalTypography,
        content     = content,
    )
}
