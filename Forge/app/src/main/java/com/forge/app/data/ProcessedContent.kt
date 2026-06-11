package com.forge.app.data

import java.io.File

enum class ContentMode { LOCAL, URL }

/**
 * Result of an input importer (folder / HTML file / URL / Markdown / text /
 * PDF). [wwwDir], when present, is a directory whose contents become
 * `assets/www/` inside the forged APK. [previewUrl] is what the preview
 * WebView should load - either `file://.../index.html` or a remote URL.
 */
data class ProcessedContent(
    val mode: ContentMode,
    val wwwDir: File?,
    val url: String? = null,
    val previewUrl: String,
    val sourceLabel: String,
    val warnings: List<String> = emptyList()
)
