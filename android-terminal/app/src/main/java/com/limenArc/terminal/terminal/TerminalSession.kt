package com.limenArc.terminal.terminal

import com.limenArc.terminal.model.LineType
import com.limenArc.terminal.model.TerminalLine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File
import java.util.UUID

class TerminalSession(
    val id: String = UUID.randomUUID().toString(),
    var title: String = "Session",
    private val scope: CoroutineScope,
    workingDirectory: File = File(System.getProperty("user.home") ?: "/data"),
) {
    private val executor = CommandExecutor(workingDirectory)

    private val _lines = MutableStateFlow<List<TerminalLine>>(emptyList())
    val lines: StateFlow<List<TerminalLine>> = _lines.asStateFlow()

    private val _isRunning = MutableStateFlow(false)
    val isRunning: StateFlow<Boolean> = _isRunning.asStateFlow()

    val currentDir: File get() = executor.currentDir

    private var runningJob: Job? = null

    private val commandHistory = mutableListOf<String>()
    private var historyIndex = -1

    init {
        appendSystem("LimenArc Terminal v1.0")
        appendSystem("Type 'help' for available commands.")
        appendSystem("")
    }

    fun execute(command: String) {
        if (command.isBlank()) return
        commandHistory.add(command)
        historyIndex = commandHistory.size

        appendLine(TerminalLine("❯ $command", LineType.COMMAND))

        runningJob?.cancel()
        runningJob = scope.launch {
            _isRunning.value = true
            try {
                executor.execute(command).collect { output ->
                    if (output.isNotEmpty()) appendOutput(output)
                }
            } finally {
                _isRunning.value = false
            }
        }
    }

    fun historyUp(): String? {
        if (commandHistory.isEmpty()) return null
        historyIndex = (historyIndex - 1).coerceAtLeast(0)
        return commandHistory.getOrNull(historyIndex)
    }

    fun historyDown(): String? {
        historyIndex = (historyIndex + 1).coerceAtMost(commandHistory.size)
        return commandHistory.getOrNull(historyIndex)
    }

    fun clear() { _lines.value = emptyList() }

    fun interruptCurrent() { runningJob?.cancel(); _isRunning.value = false }

    private fun appendLine(line: TerminalLine) {
        _lines.update { it + line }
    }

    private fun appendOutput(text: String) = appendLine(TerminalLine(text, LineType.OUTPUT))
    private fun appendSystem(text: String) = appendLine(TerminalLine(text, LineType.SYSTEM))
}
