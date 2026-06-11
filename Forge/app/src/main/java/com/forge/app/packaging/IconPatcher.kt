package com.forge.app.packaging

import android.graphics.Bitmap
import java.io.BufferedOutputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

/**
 * Step 3 of the template-injection pipeline: replaces the launcher icon
 * PNGs (`res/mipmap-*/ic_launcher.png` and `ic_launcher_round.png`) with a
 * resized copy of the user's chosen image (or a generated initials icon).
 *
 * Each density gets its own resize so the icon looks crisp at every size,
 * matching the template's existing `mipmap-*` buckets.
 */
object IconPatcher {

    private val ICON_PATTERN =
        Regex("""res/mipmap-([a-z]+)(?:-v\d+)?/ic_launcher(_round)?\.(png|webp)""")

    private val DENSITY_PX = mapOf(
        "mdpi" to 48,
        "hdpi" to 72,
        "xhdpi" to 96,
        "xxhdpi" to 144,
        "xxxhdpi" to 192,
    )

    fun patch(inputApk: File, outputApk: File, icon: Bitmap) {
        ZipFile(inputApk).use { zip ->
            ZipOutputStream(BufferedOutputStream(FileOutputStream(outputApk))).use { zos ->
                for (entry in java.util.Collections.list(zip.entries())) {
                    if (entry.isDirectory) continue
                    val match = ICON_PATTERN.matchEntire(entry.name)
                    val bytes = if (match != null) {
                        val density = match.groupValues[1]
                        val sizePx = DENSITY_PX[density] ?: 48
                        renderPng(icon, sizePx)
                    } else {
                        zip.getInputStream(entry).use { it.readBytes() }
                    }

                    val outEntry = ZipEntry(entry.name)
                    outEntry.method = ZipEntry.DEFLATED
                    zos.putNextEntry(outEntry)
                    zos.write(bytes)
                    zos.closeEntry()
                }
            }
        }
    }

    private fun renderPng(icon: Bitmap, sizePx: Int): ByteArray {
        val scaled = Bitmap.createScaledBitmap(icon, sizePx, sizePx, true)
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.PNG, 100, out)
        if (scaled !== icon) scaled.recycle()
        return out.toByteArray()
    }
}
