package com.forge.app.input

import android.content.Context
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import com.forge.app.data.ContentMode
import com.forge.app.data.ProcessedContent
import java.io.File

/**
 * Imports a single HTML file. It becomes `index.html`. Relative links to
 * other local files won't resolve (we only have access to the one file via
 * SAF), which is surfaced to the user as a warning.
 */
object HtmlFileImporter {

    suspend fun import(context: Context, fileUri: Uri): ProcessedContent {
        val dest = WorkDir.create(context)
        val indexFile = File(dest, "index.html")

        context.contentResolver.openInputStream(fileUri)?.use { input ->
            indexFile.outputStream().use { output -> input.copyTo(output) }
        } ?: error("Could not read the selected file")

        val name = DocumentFile.fromSingleUri(context, fileUri)?.name ?: "index.html"
        val warnings = mutableListOf<String>()

        val text = indexFile.readText()
        if (Regex("""(src|href)\s*=\s*["'](?!https?:|data:|#)[^"']+""", RegexOption.IGNORE_CASE)
                .containsMatchIn(text)
        ) {
            warnings.add(
                "This page links to other local files (images, CSS, scripts). " +
                    "Only the HTML itself was imported - pick a folder instead if " +
                    "you need those files bundled too."
            )
        }

        return ProcessedContent(
            mode = ContentMode.LOCAL,
            wwwDir = dest,
            previewUrl = "file://${indexFile.absolutePath}",
            sourceLabel = name,
            warnings = warnings
        )
    }
}
