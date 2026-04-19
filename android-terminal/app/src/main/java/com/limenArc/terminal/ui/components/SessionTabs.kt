package com.limenArc.terminal.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.limenArc.terminal.terminal.TerminalSession
import com.limenArc.terminal.ui.theme.*

@Composable
fun SessionTabs(
    sessions: List<TerminalSession>,
    activeId: String?,
    onSelect: (String) -> Unit,
    onClose: (String) -> Unit,
    onNew: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(TerminalSurface)
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 4.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        sessions.forEach { session ->
            val isActive = session.id == activeId
            Row(
                modifier = Modifier
                    .padding(end = 4.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(if (isActive) TerminalSurfaceAlt else TerminalBackground)
                    .clickable { onSelect(session.id) }
                    .padding(horizontal = 10.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = session.title,
                    color = if (isActive) TerminalGreen else TerminalTextDim,
                    fontSize = 12.sp,
                )
                if (sessions.size > 1) {
                    Spacer(Modifier.width(6.dp))
                    Icon(
                        Icons.Default.Close,
                        contentDescription = "Close",
                        tint = TerminalTextDim,
                        modifier = Modifier
                            .size(14.dp)
                            .clickable { onClose(session.id) },
                    )
                }
            }
        }

        IconButton(onClick = onNew, modifier = Modifier.size(28.dp)) {
            Icon(Icons.Default.Add, contentDescription = "New Session", tint = TerminalGreen, modifier = Modifier.size(18.dp))
        }
    }
}
