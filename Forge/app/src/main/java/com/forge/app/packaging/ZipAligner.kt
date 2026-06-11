package com.forge.app.packaging

import java.io.FilterOutputStream
import java.io.OutputStream

/**
 * On-device zipalign. `aapt2`/`zipalign` aren't available on Android, so
 * this reimplements the relevant part of the algorithm: every **STORED**
 * (uncompressed) zip entry's data must start at a file offset that is a
 * multiple of [ALIGNMENT_BYTES] (4), so it can be safely mmap'd. DEFLATED
 * entries don't need this since they're never mmap'd directly.
 *
 * The trick is a "padding" extra field in the local file header: its length
 * is chosen so that `localHeaderOffset + LOCAL_HEADER_FIXED_SIZE +
 * fileName.length + extra.length` is a multiple of the alignment.
 */
object ZipAligner {

    const val ALIGNMENT_BYTES = 4

    /** Size of the fixed part of a ZIP local file header, before name/extra. */
    private const val LOCAL_HEADER_FIXED_SIZE = 30

    /**
     * Computes the extra-field bytes to attach to a STORED entry so its data
     * begins on an [alignment]-byte boundary.
     *
     * @param currentOffset byte offset in the output stream where this
     *   entry's local file header will start.
     * @param fileNameBytes UTF-8 encoded entry name length.
     */
    fun paddingExtraField(
        currentOffset: Long,
        fileNameBytes: Int,
        alignment: Int = ALIGNMENT_BYTES
    ): ByteArray {
        if (alignment <= 1) return ByteArray(0)

        val headerSizeWithoutExtra = currentOffset + LOCAL_HEADER_FIXED_SIZE + fileNameBytes
        var needed = (alignment - (headerSizeWithoutExtra % alignment)) % alignment
        if (needed == 0L) return ByteArray(0)

        // An extra-field record needs at least 4 bytes (2 for id, 2 for
        // length). If the gap is smaller than that, push it out by one
        // alignment unit so the record still fits.
        if (needed < 4) needed += alignment

        val data = ByteArray(needed.toInt())
        // Header ID 0x0000 is reserved/unused by the ZIP spec and is widely
        // treated by readers (including Android's own) as ignorable padding.
        data[0] = 0x00
        data[1] = 0x00
        val payloadLen = needed.toInt() - 4
        data[2] = (payloadLen and 0xFF).toByte()
        data[3] = ((payloadLen shr 8) and 0xFF).toByte()
        return data
    }

    /** Returns true if [offset] is aligned to [alignment] bytes. */
    fun isAligned(offset: Long, alignment: Int = ALIGNMENT_BYTES): Boolean =
        offset % alignment == 0L
}

/** Tracks the number of bytes written so local file header offsets can be computed. */
class CountingOutputStream(out: OutputStream) : FilterOutputStream(out) {
    var count: Long = 0
        private set

    override fun write(b: Int) {
        out.write(b)
        count++
    }

    override fun write(b: ByteArray, off: Int, len: Int) {
        out.write(b, off, len)
        count += len
    }
}
