package com.forge.app.input

import android.content.Context
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import com.forge.app.data.ContentMode
import com.forge.app.data.ProcessedContent
import org.commonmark.parser.Parser
import org.commonmark.renderer.html.HtmlRenderer
import java.io.File

/** Converts a Markdown file into a styled standalone HTML page. */
object MarkdownImporter {

    suspend fun import(context: Context, fileUri: Uri): ProcessedContent {
        val markdown = context.contentResolver.openInputStream(fileUri)?.use {
            it.bufferedReader().readText()
        } ?: error("Could not read the selected file")

        val name = DocumentFile.fromSingleUri(context, fileUri)?.name ?: "document.md"
        val title = name.substringBeforeLast('.')

        val parser = Parser.builder().build()
        val renderer = HtmlRenderer.builder().build()
        val bodyHtml = renderer.render(parser.parse(markdown))

        val dest = WorkDir.create(context)
        val indexFile = File(dest, "index.html")
        indexFile.writeText(wrapHtml(title, bodyHtml))

        return ProcessedContent(
            mode = ContentMode.LOCAL,
            wwwDir = dest,
            previewUrl = "file://${indexFile.absolutePath}",
            sourceLabel = name
        )
    }

    private fun wrapHtml(title: String, body: String): String = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>${escapeHtml(title)}</title>
        <style>
          :root { color-scheme: light dark; }
          body {
            font-family: -apple-system, Roboto, "Segoe UI", sans-serif;
            line-height: 1.6;
            max-width: 760px;
            margin: 0 auto;
            padding: 24px;
          }
          pre, code {
            background: rgba(127,127,127,0.15);
            border-radius: 6px;
            padding: 2px 6px;
            font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
          }
          pre code { padding: 0; }
          pre { padding: 12px; overflow-x: auto; }
          img { max-width: 100%; }
          blockquote {
            border-left: 4px solid #FF7A1A;
            margin: 0;
            padding: 0 1em;
            opacity: 0.85;
          }
          table { border-collapse: collapse; }
          th, td { border: 1px solid rgba(127,127,127,0.4); padding: 6px 10px; }
        </style>
        </head>
        <body>
        $body
        </body>
        </html>
    """.trimIndent()

    private fun escapeHtml(text: String) = text
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
}
