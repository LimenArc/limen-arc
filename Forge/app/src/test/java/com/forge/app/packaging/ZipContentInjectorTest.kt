package com.forge.app.packaging

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

class ZipContentInjectorTest {

    @get:Rule
    val tmp = TemporaryFolder()

    private fun buildFakeTemplateApk(): File {
        val apk = tmp.newFile("template.apk")
        ZipOutputStream(apk.outputStream()).use { zos ->
            // A STORED entry, like resources.arsc in a real APK.
            val arsc = ByteArray(37) { it.toByte() }
            val arscEntry = ZipEntry("resources.arsc")
            arscEntry.method = ZipEntry.STORED
            arscEntry.size = arsc.size.toLong()
            arscEntry.compressedSize = arsc.size.toLong()
            val crc = java.util.zip.CRC32()
            crc.update(arsc)
            arscEntry.crc = crc.value
            zos.putNextEntry(arscEntry)
            zos.write(arsc)
            zos.closeEntry()

            // Manifest, untouched by this step.
            zos.putNextEntry(ZipEntry("AndroidManifest.xml"))
            zos.write("manifest-bytes".toByteArray())
            zos.closeEntry()

            // Old config + old www content that should be replaced.
            zos.putNextEntry(ZipEntry("assets/forge.json"))
            zos.write("""{"mode":"local"}""".toByteArray())
            zos.closeEntry()

            zos.putNextEntry(ZipEntry("assets/www/index.html"))
            zos.write("<html>old placeholder</html>".toByteArray())
            zos.closeEntry()

            zos.putNextEntry(ZipEntry("assets/www/style.css"))
            zos.write("body{}".toByteArray())
            zos.closeEntry()
        }
        return apk
    }

    @Test
    fun `replaces www contents and config, preserves other entries`() {
        val template = buildFakeTemplateApk()
        val output = tmp.newFile("output.apk")

        val wwwDir = tmp.newFolder("www")
        File(wwwDir, "index.html").writeText("<html>Hello Forge</html>")
        val sub = File(wwwDir, "img").apply { mkdirs() }
        File(sub, "logo.png").writeBytes(byteArrayOf(1, 2, 3, 4))

        ZipContentInjector.inject(
            templateApk = template,
            outputApk = output,
            wwwDir = wwwDir,
            forgeConfigJson = """{"mode":"local"}"""
        )

        ZipFile(output).use { zip ->
            val names = java.util.Collections.list(zip.entries()).map { it.name }.toSet()

            // Old www content is gone.
            assertFalse(names.contains("assets/www/style.css"))

            // New www content is present, including subdirectories.
            assertTrue(names.contains("assets/www/index.html"))
            assertTrue(names.contains("assets/www/img/logo.png"))
            val newIndex = zip.getInputStream(zip.getEntry("assets/www/index.html")).readBytes()
            assertEquals("<html>Hello Forge</html>", String(newIndex))

            // forge.json was rewritten.
            val config = zip.getInputStream(zip.getEntry("assets/forge.json")).readBytes()
            assertEquals("""{"mode":"local"}""", String(config))

            // Untouched entries survive.
            assertTrue(names.contains("AndroidManifest.xml"))
            assertTrue(names.contains("resources.arsc"))
        }
    }

    @Test
    fun `STORED entries remain aligned after injection`() {
        val template = buildFakeTemplateApk()
        val output = tmp.newFile("output.apk")

        ZipContentInjector.inject(
            templateApk = template,
            outputApk = output,
            wwwDir = null,
            forgeConfigJson = """{"mode":"url","url":"https://example.com"}"""
        )

        // Walk the raw zip structure to find where each STORED entry's data begins.
        ZipFile(output).use { zip ->
            for (entry in java.util.Collections.list(zip.entries())) {
                if (entry.method != ZipEntry.STORED) continue
                val dataOffset = localFileHeaderDataOffset(output, entry)
                assertTrue(
                    "STORED entry '${entry.name}' data offset $dataOffset not 4-byte aligned",
                    dataOffset % ZipAligner.ALIGNMENT_BYTES == 0L
                )
            }
        }
    }

    /** Reads a local file header to compute where an entry's data actually starts. */
    private fun localFileHeaderDataOffset(zipFile: File, entry: ZipEntry): Long {
        java.io.RandomAccessFile(zipFile, "r").use { raf ->
            // ZipEntry doesn't expose the local header offset directly via
            // java.util.zip, so scan for it (fine for these small test files).
            val data = raf.readBytes()
            val nameBytes = entry.name.toByteArray(Charsets.UTF_8)
            var index = 0
            while (index < data.size - 4) {
                if (data[index] == 0x50.toByte() && data[index + 1] == 0x4b.toByte() &&
                    data[index + 2] == 0x03.toByte() && data[index + 3] == 0x04.toByte()
                ) {
                    val nameLen = (data[index + 26].toInt() and 0xFF) or ((data[index + 27].toInt() and 0xFF) shl 8)
                    val extraLen = (data[index + 28].toInt() and 0xFF) or ((data[index + 29].toInt() and 0xFF) shl 8)
                    if (nameLen == nameBytes.size) {
                        val candidateName = String(data, index + 30, nameLen, Charsets.UTF_8)
                        if (candidateName == entry.name) {
                            return (index + 30 + nameLen + extraLen).toLong()
                        }
                    }
                }
                index++
            }
            error("Local file header for ${entry.name} not found")
        }
    }

    private fun RandomAccessFile.readBytes(): ByteArray {
        val bytes = ByteArray(length().toInt())
        seek(0)
        readFully(bytes)
        return bytes
    }
}

private typealias RandomAccessFile = java.io.RandomAccessFile
