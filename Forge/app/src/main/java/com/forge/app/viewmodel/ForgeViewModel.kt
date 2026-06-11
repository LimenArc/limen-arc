package com.forge.app.viewmodel

import android.app.Application
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.forge.app.data.ProcessedContent
import com.forge.app.icon.InitialsIconGenerator
import com.forge.app.input.FolderImporter
import com.forge.app.input.HtmlFileImporter
import com.forge.app.input.MarkdownImporter
import com.forge.app.input.TextAndPdfImporter
import com.forge.app.input.UrlImporter
import com.forge.app.packaging.ApkForge
import com.forge.app.packaging.ForgeOrientation
import com.forge.app.packaging.ForgeStage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

enum class UrlMode { ONLINE_WRAPPER, SNAPSHOT }

data class ForgeUiState(
    val isLoadingContent: Boolean = false,
    val content: ProcessedContent? = null,
    val loadError: String? = null,

    val appName: String = "",
    val iconBitmap: Bitmap? = null,
    val orientation: ForgeOrientation = ForgeOrientation.UNSPECIFIED,

    val forgeStage: ForgeStage? = null,
)

class ForgeViewModel(application: Application) : AndroidViewModel(application) {

    private val _uiState = MutableStateFlow(ForgeUiState())
    val uiState: StateFlow<ForgeUiState> = _uiState.asStateFlow()

    // ---- Input loading -----------------------------------------------

    fun loadFolder(treeUri: Uri) = loadContent {
        FolderImporter.import(getApplication(), treeUri)
    }

    fun loadHtmlFile(fileUri: Uri) = loadContent {
        HtmlFileImporter.import(getApplication(), fileUri)
    }

    fun loadMarkdown(fileUri: Uri) = loadContent {
        MarkdownImporter.import(getApplication(), fileUri)
    }

    fun loadText(fileUri: Uri) = loadContent {
        TextAndPdfImporter.importText(getApplication(), fileUri)
    }

    fun loadPdf(fileUri: Uri) = loadContent {
        TextAndPdfImporter.importPdf(getApplication(), fileUri)
    }

    fun loadUrl(url: String, mode: UrlMode) = loadContent {
        when (mode) {
            UrlMode.ONLINE_WRAPPER -> UrlImporter.importOnlineWrapper(url)
            UrlMode.SNAPSHOT -> UrlImporter.importSnapshot(getApplication(), url)
        }
    }

    private fun loadContent(block: suspend () -> ProcessedContent) {
        _uiState.update { it.copy(isLoadingContent = true, loadError = null) }
        viewModelScope.launch {
            try {
                val content = withContext(Dispatchers.IO) { block() }
                val defaultIcon = InitialsIconGenerator.generate(
                    suggestedName(content.sourceLabel)
                )
                _uiState.update {
                    it.copy(
                        isLoadingContent = false,
                        content = content,
                        appName = suggestedName(content.sourceLabel),
                        iconBitmap = defaultIcon,
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(isLoadingContent = false, loadError = e.message ?: "Couldn't load that content")
                }
            }
        }
    }

    private fun suggestedName(label: String): String {
        val base = label.substringAfterLast('/')
            .substringBeforeLast('.')
            .replace(Regex("[_\\-]+"), " ")
            .trim()
        return if (base.isBlank()) "My App" else base.take(30)
    }

    // ---- Customization --------------------------------------------------

    fun setAppName(name: String) {
        _uiState.update { it.copy(appName = name) }
    }

    fun setIcon(bitmap: Bitmap) {
        _uiState.update { it.copy(iconBitmap = bitmap) }
    }

    fun setIconFromUri(uri: Uri) {
        viewModelScope.launch {
            val bitmap = withContext(Dispatchers.IO) {
                getApplication<Application>().contentResolver.openInputStream(uri)?.use {
                    BitmapFactory.decodeStream(it)
                }
            }
            if (bitmap != null) setIcon(bitmap)
        }
    }

    fun setOrientation(orientation: ForgeOrientation) {
        _uiState.update { it.copy(orientation = orientation) }
    }

    // ---- Forging ----------------------------------------------------------

    fun startForging() {
        val state = _uiState.value
        val content = state.content ?: return
        val icon = state.iconBitmap ?: InitialsIconGenerator.generate(state.appName)
        val name = state.appName.ifBlank { "My App" }

        _uiState.update { it.copy(forgeStage = ForgeStage.Injecting) }
        viewModelScope.launch {
            ApkForge.forge(getApplication(), content, name, icon, state.orientation)
                .collect { stage ->
                    _uiState.update { it.copy(forgeStage = stage) }
                }
        }
    }

    fun resetForging() {
        _uiState.update { it.copy(forgeStage = null) }
    }

    fun resetAll() {
        _uiState.value = ForgeUiState()
    }
}
