package com.limenArc.terminal.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.key.*
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.limenArc.terminal.ui.theme.*

@Composable
fun CommandInput(
    value: String,
    onValueChange: (String) -> Unit,
    onSubmit: (String) -> Unit,
    onHistoryUp: () -> Unit,
    onHistoryDown: () -> Unit,
    isRunning: Boolean,
    modifier: Modifier = Modifier,
) {
    val focusRequester = remember { FocusRequester() }

    LaunchedEffect(Unit) { focusRequester.requestFocus() }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(TerminalSurface)
            .padding(horizontal = 8.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "❯",
            color = TerminalGreen,
            fontFamily = FontFamily.Monospace,
            fontSize = 16.sp,
            modifier = Modifier.padding(end = 8.dp),
        )

        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier
                .weight(1f)
                .focusRequester(focusRequester)
                .onKeyEvent { event ->
                    if (event.type == KeyEventType.KeyDown) {
                        when (event.key) {
                            Key.Enter -> { onSubmit(value); true }
                            Key.DirectionUp -> { onHistoryUp(); true }
                            Key.DirectionDown -> { onHistoryDown(); true }
                            else -> false
                        }
                    } else false
                },
            textStyle = TextStyle(
                color = TerminalText,
                fontFamily = FontFamily.Monospace,
                fontSize = 14.sp,
            ),
            cursorBrush = SolidColor(TerminalCursor),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
            keyboardActions = KeyboardActions(onSend = { onSubmit(value) }),
            singleLine = true,
            decorationBox = { inner ->
                Box {
                    if (value.isEmpty()) {
                        Text(
                            "Enter command…",
                            color = TerminalTextDim,
                            fontFamily = FontFamily.Monospace,
                            fontSize = 14.sp,
                        )
                    }
                    inner()
                }
            },
        )

        Spacer(Modifier.width(4.dp))

        IconButton(onClick = onHistoryUp, modifier = Modifier.size(32.dp)) {
            Icon(Icons.Default.KeyboardArrowUp, "History Up", tint = TerminalTextDim, modifier = Modifier.size(20.dp))
        }
        IconButton(onClick = onHistoryDown, modifier = Modifier.size(32.dp)) {
            Icon(Icons.Default.KeyboardArrowDown, "History Down", tint = TerminalTextDim, modifier = Modifier.size(20.dp))
        }
        IconButton(
            onClick = { if (!isRunning) onSubmit(value) },
            modifier = Modifier.size(32.dp),
        ) {
            Icon(
                Icons.Default.Send,
                contentDescription = "Run",
                tint = if (isRunning) TerminalTextDim else TerminalGreen,
                modifier = Modifier.size(20.dp),
            )
        }
    }
}
