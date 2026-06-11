package com.forge.app.packaging

import java.util.zip.CRC32
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/** Shared helper for writing a single zip entry, applying [ZipAligner] padding to STORED entries. */
internal object ZipEntryWriter {

    fun write(
        zos: ZipOutputStream,
        counting: CountingOutputStream,
        name: String,
        bytes: ByteArray,
        stored: Boolean
    ) {
        val entry = ZipEntry(name)
        if (stored) {
            entry.method = ZipEntry.STORED
            entry.size = bytes.size.toLong()
            entry.compressedSize = bytes.size.toLong()
            val crc = CRC32()
            crc.update(bytes)
            entry.crc = crc.value

            val nameBytes = name.toByteArray(Charsets.UTF_8).size
            entry.setExtra(ZipAligner.paddingExtraField(counting.count, nameBytes))
        } else {
            entry.method = ZipEntry.DEFLATED
        }

        zos.putNextEntry(entry)
        zos.write(bytes)
        zos.closeEntry()
    }
}
