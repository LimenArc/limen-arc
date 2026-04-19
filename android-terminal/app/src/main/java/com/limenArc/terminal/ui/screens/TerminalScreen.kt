package com.limenArc.terminal.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.limenArc.terminal.ui.components.CommandInput
import com.limenArc.terminal.ui.components.SessionTabs
import com.limenArc.terminal.ui.components.TerminalOutput
import com.limenArc.terminal.ui.theme.TerminalGreen
import com.limenArc.terminal.ui.theme.TerminalRed
import com.limenArc.terminal.ui.theme.TerminalSurface
import com.limenArc.terminal.ui.theme.TerminalText
import com.limenArc.terminal.viewmodel.TerminalViewModel
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TerminalScreen(
    onOpenDrawer: () -> Unit,
    vm: TerminalViewModel = viewModel(),
) {
    val sessions by vm.sessions.collectAsStateWithLifecycle()
    val activeId by vm.activeSessionId.collectAsStateWithLifecycle()
    val session = vm.activeSession

    val lines by (session?.lines?.collectAsStateWithLifecycle(emptyList()) ?: remember { mutableStateOf(emptyList()) })
    val isRunning by (session?.isRunning?.collectAsStateWithLifecycle(false) ?: remember { mutableStateOf(false) })

    var input by remember { mutableStateOf("") }
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    LaunchedEffect(lines.size) {
        if (lines.isNotEmpty()) listState.animateScrollToItem(lines.size - 1)
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text("Terminal", color = TerminalGreen) },
                navigationIcon = {
                    IconButton(onClick = onOpenDrawer) {
                        Icon(Icons.Default.Menu, "Menu", tint = TerminalText)
                    }
                },
                actions = {
                    if (isRunning) {
                        IconButton(onClick = { vm.interruptActive() }) {
                            Icon(Icons.Default.Stop, "Interrupt", tint = TerminalRed)
                        }
                    }
                    IconButton(onClick = { vm.clearActive() }) {
                        Icon(Icons.Default.Clear, "Clear", tint = TerminalText)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = TerminalSurface),
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            SessionTabs(
                sessions = sessions,
                activeId = activeId,
                onSelect = vm::selectSession,
                onClose = vm::closeSession,
                onNew = { vm.newSession() },
            )

            HorizontalDivider(color = MaterialTheme.colorScheme.outline, thickness = 0.5.dp)

            TerminalOutput(
                lines = lines,
                listState = listState,
                modifier = Modifier.weight(1f).fillMaxWidth(),
            )

            HorizontalDivider(color = MaterialTheme.colorScheme.outline, thickness = 0.5.dp)

            CommandInput(
                value = input,
                onValueChange = { input = it },
                onSubmit = { cmd ->
                    vm.executeCommand(cmd)
                    input = ""
                    scope.launch { if (lines.isNotEmpty()) listState.animateScrollToItem(lines.size - 1) }
                },
                onHistoryUp = { input = session?.historyUp() ?: input },
                onHistoryDown = { input = session?.historyDown() ?: input },
                isRunning = isRunning,
            )
        }
    }
}
