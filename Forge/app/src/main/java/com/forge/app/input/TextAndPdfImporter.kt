package com.forge.app.input

import android.content.Context
import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import androidx.documentfile.provider.DocumentFile
import com.forge.app.data.ContentMode
import com.forge.app.data.ProcessedContent
import java.io.File
import java.io.FileOutputStream

/**
 * Wraps plain-text or PDF input in a simple, readable viewer page.
 *
 * PDFs are rasterised page-by-page on-device with [PdfRenderer] (API 21+)
 * into PNGs, which are then laid out in a scrolling HTML page. This is
 * "best effort": text won't be selectable and very large PDFs may take a
 * while and produce a sizeable APK.
 */
object TextAndPdfImporter {

    suspend fun importText(context: Context, fileUri: Uri): ProcessedContent {
        val text = context.contentResolver.openInputStream(fileUri)?.use {
            it.bufferedReader().readText()
        } ?: error("Could not read the selected file")

        val name = DocumentFile.fromSingleUri(context, fileUri)?.name ?: "document.txt"
        val dest = WorkDir.create(context)
        val indexFile = File(dest, "index.html")
        indexFile.writeText(
            """
            <!DOCTYPE html>
            <html><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>${escapeHtml(name)}</title>
            <style>
              :root { color-scheme: light dark; }
              body { font-family: ui-monospace, Menlo, monospace; padding: 16px; }
              pre { white-space: pre-wrap; word-wrap: break-word; }
            </style>
            </head><body><pre>${escapeHtml(text)}</pre></body></html>
            """.trimIndent()
        )

        return ProcessedContent(
            mode = ContentMode.LOCAL,
            wwwDir = dest,
            previewUrl = "file://${indexFile.absolutePath}",
            sourceLabel = name
        )
    }

    suspend fun importPdf(context: Context, fileUri: Uri): ProcessedContent {
        val name = DocumentFile.fromSingleUri(context, fileUri)?.name ?: "document.pdf"
        val dest = WorkDir.create(context)
        val pagesDir = File(dest, "pages").apply { mkdirs() }

        val tmpPdf = File(dest, "_source.pdf")
        context.contentResolver.openInputStream(fileUri)?.use { input ->
            tmpPdf.outputStream().use { output -> input.copyTo(output) }
        } ?: error("Could not read the selected file")

        val warnings = mutableListOf<String>()
        val imageNames = mutableListOf<String>()

        ParcelFileDescriptor.open(tmpPdf, ParcelFileDescriptor.MODE_READ_ONLY).use { pfd ->
            PdfRenderer(pfd).use { renderer ->
                val pageCount = renderer.pageCount
                if (pageCount > MAX_PAGES) {
                    warnings.add(
                        "This PDF has $pageCount pages; only the first $MAX_PAGES were converted."
                    )
                }
                val limit = minOf(pageCount, MAX_PAGES)
                for (i in 0 until limit) {
                    renderer.openPage(i).use { page ->
                        val scale = TARGET_WIDTH_PX.toFloat() / page.width
                        val width = TARGET_WIDTH_PX
                        val height = (page.height * scale).toInt()
                        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        bitmap.eraseColor(0xFFFFFFFF.toInt())
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)

                        val fileName = "page_%03d.png".format(i + 1)
                        FileOutputStream(File(pagesDir, fileName)).use { out ->
                            bitmap.compress(Bitmap.CompressFormat.PNG, 90, out)
                        }
                        bitmap.recycle()
                        imageNames.add(fileName)
                    }
                }
            }
        }
        tmpPdf.delete()

        val imgTags = imageNames.joinToString("\n") {
            "<img src=\"pages/$it\" alt=\"\">"
        }
        val indexFile = File(dest, "index.html")
        indexFile.writeText(
            """
            <!DOCTYPE html>
            <html><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>${escapeHtml(name)}</title>
            <style>
              body { margin: 0; background: #525659; text-align: center; }
              img { display: block; max-width: 100%; margin: 8px auto; box-shadow: 0 2px 8px rgba(0,0,0,0.4); }
            </style>
            </head><body>$imgTags</body></html>
            """.trimIndent()
        )

        return ProcessedContent(
            mode = ContentMode.LOCAL,
            wwwDir = dest,
            previewUrl = "file://${indexFile.absolutePath}",
            sourceLabel = name,
            warnings = warnings
        )
    }

    private fun escapeHtml(text: String) = text
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")

    private const val MAX_PAGES = 60
    private const val TARGET_WIDTH_PX = 1080
}
