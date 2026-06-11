package com.forge.app.input

import com.forge.app.data.ContentMode
import com.forge.app.data.ProcessedContent
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.jsoup.Jsoup
import org.jsoup.nodes.Element
import java.io.File
import java.net.URI
import java.net.URL
import java.security.MessageDigest

/**
 * Handles the two URL-based input modes:
 *  - [importOnlineWrapper]: the forged app's WebView simply loads the URL
 *    live (requires internet at runtime).
 *  - [importSnapshot]: best-effort offline copy. Downloads the page and
 *    inlines same-origin CSS/JS/images so the page works without a
 *    connection. Cross-origin resources (CDNs, fonts, embeds, anything
 *    behind JS-driven loading) are left as live links and reported back to
 *    the user as warnings.
 */
object UrlImporter {

    fun importOnlineWrapper(url: String): ProcessedContent {
        val normalized = normalizeUrl(url)
        return ProcessedContent(
            mode = ContentMode.URL,
            wwwDir = null,
            url = normalized,
            previewUrl = normalized,
            sourceLabel = normalized
        )
    }

    suspend fun importSnapshot(context: android.content.Context, url: String): ProcessedContent =
        withContext(Dispatchers.IO) {
            val normalized = normalizeUrl(url)
            val pageUrl = URI(normalized).toURL()
            val doc = Jsoup.connect(normalized)
                .userAgent("Mozilla/5.0 (Forge offline snapshot)")
                .timeout(20_000)
                .get()

            val dest = WorkDir.create(context)
            val assetsDir = File(dest, "assets").apply { mkdirs() }
            val warnings = mutableListOf<String>()
            var downloaded = 0

            fun maybeInline(el: Element, attr: String) {
                val raw = el.attr(attr)
                if (raw.isBlank() || raw.startsWith("data:")) return
                val resolved = try {
                    URI(pageUrl.toString()).resolve(raw).toURL()
                } catch (e: Exception) {
                    return
                }
                if (resolved.host != pageUrl.host) {
                    // Cross-origin: leave it as a live link.
                    el.attr(attr, resolved.toString())
                    return
                }
                if (downloaded >= MAX_ASSETS) {
                    warnings.add("Reached the snapshot asset limit ($MAX_ASSETS); some resources were left as live links.")
                    el.attr(attr, resolved.toString())
                    return
                }
                try {
                    val bytes = resolved.openStream().use { it.readBytes() }
                    val ext = resolved.path.substringAfterLast('.', "").take(8).ifBlank { "bin" }
                    val name = sha1(resolved.toString()).take(16) + "." + ext
                    File(assetsDir, name).writeBytes(bytes)
                    el.attr(attr, "assets/$name")
                    downloaded++
                } catch (e: Exception) {
                    warnings.add("Couldn't download ${resolved}: ${e.message}")
                    el.attr(attr, resolved.toString())
                }
            }

            doc.select("link[rel~=(?i)stylesheet]").forEach { maybeInline(it, "href") }
            doc.select("script[src]").forEach { maybeInline(it, "src") }
            doc.select("img[src]").forEach { maybeInline(it, "src") }

            if (doc.select("script:not([src])").isNotEmpty()) {
                warnings.add("This page uses scripts that load content dynamically; some functionality may not work offline.")
            }

            val indexFile = File(dest, "index.html")
            indexFile.writeText(doc.outerHtml())

            ProcessedContent(
                mode = ContentMode.LOCAL,
                wwwDir = dest,
                previewUrl = "file://${indexFile.absolutePath}",
                sourceLabel = normalized,
                warnings = warnings + "Snapshot mode is best-effort: pages with heavy JavaScript or logins may not work fully offline."
            )
        }

    private fun normalizeUrl(url: String): String {
        val trimmed = url.trim()
        return if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
            trimmed
        } else {
            "https://$trimmed"
        }
    }

    private fun sha1(text: String): String {
        val digest = MessageDigest.getInstance("SHA-1").digest(text.toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }

    private const val MAX_ASSETS = 60
}
