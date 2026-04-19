package com.limenArc.terminal.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.limenArc.terminal.terminal.TerminalSession
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class TerminalViewModel : ViewModel() {

    private val _sessions = MutableStateFlow<List<TerminalSession>>(emptyList())
    val sessions: StateFlow<List<TerminalSession>> = _sessions.asStateFlow()

    private val _activeSessionId = MutableStateFlow<String?>(null)
    val activeSessionId: StateFlow<String?> = _activeSessionId.asStateFlow()

    val activeSession: TerminalSession?
        get() = _sessions.value.find { it.id == _activeSessionId.value }

    init { newSession() }

    fun newSession(title: String? = null): TerminalSession {
        val session = TerminalSession(
            title = title ?: "Session ${_sessions.value.size + 1}",
            scope = viewModelScope,
        )
        _sessions.value = _sessions.value + session
        _activeSessionId.value = session.id
        return session
    }

    fun selectSession(id: String) {
        _activeSessionId.value = id
    }

    fun closeSession(id: String) {
        val updated = _sessions.value.filter { it.id != id }
        _sessions.value = updated
        if (_activeSessionId.value == id) {
            _activeSessionId.value = updated.lastOrNull()?.id
        }
        if (updated.isEmpty()) newSession()
    }

    fun executeCommand(command: String) {
        activeSession?.execute(command)
    }

    fun clearActive() { activeSession?.clear() }
    fun interruptActive() { activeSession?.interruptCurrent() }
}
