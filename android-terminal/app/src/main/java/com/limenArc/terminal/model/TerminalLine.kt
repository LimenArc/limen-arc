package com.limenArc.terminal.model

import androidx.compose.ui.graphics.Color

enum class LineType { COMMAND, OUTPUT, ERROR, SYSTEM }

data class TerminalLine(
    val text: String,
    val type: LineType = LineType.OUTPUT,
    val color: Color? = null,
)
