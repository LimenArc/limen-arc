package com.forge.app.input

import android.content.Context
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import com.forge.app.data.ContentMode
import com.forge.app.data.ProcessedContent
import java.io.File

/**
 * Imports a folder of HTML/CSS/JS picked via Storage Access Framework
 * (ACTION_OPEN_DOCUMENT_TREE). If no `index.html` is found at the top level,
 * one is generated: it uses the first `.html` file found, or falls back to a
 * simple file listing so the user always has something to preview.
 */
object FolderImporter {

    suspend fun import(context: Context, treeUri: Uri): ProcessedContent {
        val root = DocumentFile.fromTreeUri(context, treeUri)
            ?: error("Could not open the selected folder")

        val dest = WorkDir.create(context)
        val warnings = mutableListOf<String>()

        copyTree(context, root, dest)

        val indexFile = File(dest, "index.html")
        if (!indexFile.exists()) {
            val firstHtml = dest.walkTopDown().firstOrNull {
                it.isFile && it.extension.equals("html", ignoreCase = true)
            }
            if (firstHtml != null) {
                // Promote the first HTML file we find to be the entry point.
                firstHtml.copyTo(indexFile, overwrite = true)
                warnings.add("No index.html was found; using ${firstHtml.name} as the home page.")
            } else {
                generateListingPage(dest, indexFile)
                warnings.add("No HTML files were found; generated a simple file listing instead.")
            }
        }

        return ProcessedContent(
            mode = ContentMode.LOCAL,
            wwwDir = dest,
            previewUrl = "file://${indexFile.absolutePath}",
            sourceLabel = root.name ?: "Selected folder",
            warnings = warnings
        )
    }

    private fun copyTree(context: Context, doc: DocumentFile, destDir: File) {
        for (child in doc.listFiles()) {
            val name = child.name ?: continue
            if (child.isDirectory) {
                val childDir = File(destDir, name).apply { mkdirs() }
                copyTree(context, child, childDir)
            } else {
                val outFile = File(destDir, name)
                context.contentResolver.openInputStream(child.uri)?.use { input ->
                    outFile.outputStream().use { output -> input.copyTo(output) }
                }
            }
        }
    }

    private fun generateListingPage(dir: File, indexFile: File) {
        val files = dir.listFiles()?.sortedBy { it.name } ?: emptyList()
        val items = files.joinToString("\n") { f ->
            "<li><a href=\"${f.name}\">${f.name}</a></li>"
        }
        indexFile.writeText(
            """
            <!DOCTYPE html>
            <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Files</title></head>
            <body style="font-family:sans-serif;padding:24px;">
            <h1>Files</h1>
            <ul>$items</ul>
            </body></html>
            """.trimIndent()
        )
    }
}
