package com.forge.app.packaging

import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

/**
 * Step 1 of the template-injection pipeline: copies every entry from the
 * compiled template APK into a new APK, *except* `assets/www/*` and
 * `assets/forge.json`, then writes the user's content (and a fresh
 * `forge.json`) in their place.
 *
 * Each entry's original compression method (STORED vs DEFLATED) is
 * preserved, and STORED entries are re-aligned with [ZipAligner] so the
 * result stays a valid, mmap-friendly APK.
 */
object ZipContentInjector {

    private const val WWW_PREFIX = "assets/www/"
    private const val FORGE_CONFIG_PATH = "assets/forge.json"

    /**
     * @param templateApk the extracted template APK (input).
     * @param outputApk where the repackaged (unsigned, unpatched) APK is written.
     * @param wwwDir directory whose contents become `assets/www/**` (for
     *   "local" mode), or null for "url" mode where forge.json alone decides
     *   what loads.
     * @param forgeConfigJson contents of `assets/forge.json` to write.
     */
    fun inject(templateApk: File, outputApk: File, wwwDir: File?, forgeConfigJson: String) {
        ZipFile(templateApk).use { zip ->
            val counting = CountingOutputStream(BufferedOutputStream(FileOutputStream(outputApk)))
            ZipOutputStream(counting).use { zos ->
                val entries = java.util.Collections.list(zip.entries()).sortedBy { it.name }
                for (entry in entries) {
                    if (entry.isDirectory) continue
                    if (entry.name.startsWith(WWW_PREFIX) || entry.name == FORGE_CONFIG_PATH) continue
                    val bytes = zip.getInputStream(entry).use { it.readBytes() }
                    writeEntry(zos, counting, entry.name, bytes, preferStored = entry.method == ZipEntry.STORED)
                }

                // Fresh config describing how this forged app should behave.
                writeEntry(zos, counting, FORGE_CONFIG_PATH, forgeConfigJson.toByteArray(Charsets.UTF_8))

                // The user's content.
                wwwDir?.let { dir ->
                    dir.walkTopDown().filter { it.isFile }.sortedBy { it.path }.forEach { file ->
                        val relative = file.relativeTo(dir).path.replace(File.separatorChar, '/')
                        writeEntry(zos, counting, "$WWW_PREFIX$relative", file.readBytes(), preferStored = false)
                    }
                }
            }
        }
    }

    private fun writeEntry(
        zos: ZipOutputStream,
        counting: CountingOutputStream,
        name: String,
        bytes: ByteArray,
        preferStored: Boolean = false
    ) = ZipEntryWriter.write(zos, counting, name, bytes, stored = preferStored)
}
