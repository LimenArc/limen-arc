package com.limenArc.terminal.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.limenArc.terminal.model.LineType
import com.limenArc.terminal.model.TerminalLine
import com.limenArc.terminal.ui.theme.*

@Composable
fun TerminalOutput(
    lines: List<TerminalLine>,
    listState: LazyListState,
    modifier: Modifier = Modifier,
) {
    SelectionContainer {
        LazyColumn(
            state = listState,
            modifier = modifier
                .background(TerminalBackground)
                .padding(horizontal = 8.dp, vertical = 4.dp),
            verticalArrangement = Arrangement.spacedBy(1.dp),
        ) {
            items(lines, key = { System.identityHashCode(it).toString() + it.text.take(10) }) { line ->
                TerminalLineView(line)
            }
        }
    }
}

@Composable
private fun TerminalLineView(line: TerminalLine) {
    val color = line.color ?: when (line.type) {
        LineType.COMMAND -> TerminalGreen
        LineType.ERROR   -> TerminalRed
        LineType.SYSTEM  -> TerminalTextDim
        LineType.OUTPUT  -> TerminalText
    }
    val hScroll = rememberScrollState()
    Text(
        text = line.text,
        color = color,
        fontFamily = FontFamily.Monospace,
        fontSize = 13.sp,
        lineHeight = 18.sp,
        softWrap = false,
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(hScroll),
    )
}
