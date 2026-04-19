package com.limenArc.terminal.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.limenArc.terminal.model.FileItem
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.File

class FileBrowserViewModel : ViewModel() {

    private val _currentPath = MutableStateFlow(File(System.getProperty("user.home") ?: "/storage/emulated/0"))
    val currentPath: StateFlow<File> = _currentPath.asStateFlow()

    private val _files = MutableStateFlow<List<FileItem>>(emptyList())
    val files: StateFlow<List<FileItem>> = _files.asStateFlow()

    private val _showHidden = MutableStateFlow(false)
    val showHidden: StateFlow<Boolean> = _showHidden.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    private val backStack = mutableListOf<File>()

    init { loadDirectory(_currentPath.value) }

    fun navigateTo(dir: File) {
        backStack.add(_currentPath.value)
        _currentPath.value = dir
        loadDirectory(dir)
    }

    fun navigateUp(): Boolean {
        if (backStack.isNotEmpty()) {
            val prev = backStack.removeLast()
            _currentPath.value = prev
            loadDirectory(prev)
            return true
        }
        val parent = _currentPath.value.parentFile
        if (parent != null && parent != _currentPath.value) {
            _currentPath.value = parent
            loadDirectory(parent)
            return true
        }
        return false
    }

    fun toggleHidden() {
        _showHidden.value = !_showHidden.value
        loadDirectory(_currentPath.value)
    }

    fun refresh() { loadDirectory(_currentPath.value) }

    private fun loadDirectory(dir: File) {
        viewModelScope.launch(Dispatchers.IO) {
            _isLoading.value = true
            _error.value = null
            runCatching {
                val entries = dir.listFiles()
                    ?.filter { _showHidden.value || !it.isHidden }
                    ?.map { FileItem(it) }
                    ?.sortedWith(compareBy({ !it.file.isDirectory }, { it.name.lowercase() }))
                    ?: emptyList()
                _files.value = entries
            }.onFailure {
                _error.value = "Cannot read directory: ${it.message}"
                _files.value = emptyList()
            }
            _isLoading.value = false
        }
    }

    fun formatSize(bytes: Long): String = when {
        bytes < 1_024        -> "$bytes B"
        bytes < 1_048_576    -> "${"%.1f".format(bytes / 1_024f)} KB"
        bytes < 1_073_741_824 -> "${"%.1f".format(bytes / 1_048_576f)} MB"
        else                 -> "${"%.1f".format(bytes / 1_073_741_824f)} GB"
    }
}
