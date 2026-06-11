package com.forge.app.packaging

import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

/**
 * Final step before signing: rewrites every entry of [inputApk] into
 * [outputApk], re-applying [ZipAligner] padding to STORED entries.
 *
 * Both [ManifestPatcher] (via ARSCLib's own zip writer) and [IconPatcher]
 * rewrite the archive and don't preserve the alignment [ZipContentInjector]
 * set up, so this pass runs last to guarantee the APK handed to the signer
 * is properly aligned.
 */
object ApkRealigner {

    fun realign(inputApk: File, outputApk: File) {
        ZipFile(inputApk).use { zip ->
            val counting = CountingOutputStream(BufferedOutputStream(FileOutputStream(outputApk)))
            ZipOutputStream(counting).use { zos ->
                for (entry in java.util.Collections.list(zip.entries()).sortedBy { it.name }) {
                    if (entry.isDirectory) continue
                    val bytes = zip.getInputStream(entry).use { it.readBytes() }
                    ZipEntryWriter.write(
                        zos,
                        counting,
                        entry.name,
                        bytes,
                        stored = entry.method == ZipEntry.STORED
                    )
                }
            }
        }
    }
}
