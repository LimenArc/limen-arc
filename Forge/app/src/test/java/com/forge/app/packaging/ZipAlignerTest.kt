package com.forge.app.packaging

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ZipAlignerTest {

    @Test
    fun `padding produces aligned data offsets for a range of inputs`() {
        for (offset in 0L..200L) {
            for (nameLength in listOf(1, 5, 12, 30)) {
                val padding = ZipAligner.paddingExtraField(offset, nameLength)
                val dataOffset = offset + 30 /* fixed header */ + nameLength + padding.size
                assertTrue(
                    "offset=$offset nameLength=$nameLength padding=${padding.size} -> dataOffset=$dataOffset",
                    ZipAligner.isAligned(dataOffset)
                )
            }
        }
    }

    @Test
    fun `no padding needed when already aligned`() {
        // header(30) + name(2) = 32, already a multiple of 4
        val padding = ZipAligner.paddingExtraField(currentOffset = 0, fileNameBytes = 2)
        assertEquals(0, padding.size)
    }

    @Test
    fun `padding extra field is well-formed when present`() {
        // header(30) + name(1) = 31 -> needs 1 byte to reach 32, but the
        // minimum extra-field record is 4 bytes, so it should pad to 4
        // (bringing the total to 36, the next multiple of 4 after 31 that
        // also leaves room for a 4-byte record).
        val padding = ZipAligner.paddingExtraField(currentOffset = 0, fileNameBytes = 1)
        assertTrue(padding.isNotEmpty())
        assertTrue(padding.size >= 4)
        // ID field (first 2 bytes) = 0x0000
        assertEquals(0x00, padding[0].toInt())
        assertEquals(0x00, padding[1].toInt())
        // declared payload length matches the remaining bytes
        val declaredLen = (padding[2].toInt() and 0xFF) or ((padding[3].toInt() and 0xFF) shl 8)
        assertEquals(padding.size - 4, declaredLen)

        val dataOffset = 0L + 30 + 1 + padding.size
        assertTrue(ZipAligner.isAligned(dataOffset))
    }
}
