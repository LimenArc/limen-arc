package com.forge.app.output

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File

/** Writes the finished, signed APK to `Downloads/Forge/<name>.apk`. */
object OutputWriter {

    private const val RELATIVE_DIR = "Forge"

    fun writeToDownloads(context: Context, signedApk: File, fileName: String): Uri {
        val safeName = if (fileName.endsWith(".apk", ignoreCase = true)) fileName else "$fileName.apk"

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            writeViaMediaStore(context, signedApk, safeName)
        } else {
            writeLegacy(signedApk, safeName)
        }
    }

    private fun writeViaMediaStore(context: Context, signedApk: File, fileName: String): Uri {
        val resolver = context.contentResolver
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI

        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, "application/vnd.android.package-archive")
            put(MediaStore.Downloads.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/$RELATIVE_DIR")
            put(MediaStore.Downloads.IS_PENDING, 1)
        }

        val itemUri = resolver.insert(collection, values)
            ?: error("Could not create the output file in Downloads/$RELATIVE_DIR")

        resolver.openOutputStream(itemUri)?.use { out ->
            signedApk.inputStream().use { input -> input.copyTo(out) }
        } ?: error("Could not write to the output file")

        values.clear()
        values.put(MediaStore.Downloads.IS_PENDING, 0)
        resolver.update(itemUri, values, null, null)

        return itemUri
    }

    private fun writeLegacy(signedApk: File, fileName: String): Uri {
        val downloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val dir = File(downloads, RELATIVE_DIR).apply { mkdirs() }
        val outFile = File(dir, fileName)
        signedApk.inputStream().use { input ->
            outFile.outputStream().use { output -> input.copyTo(output) }
        }
        return Uri.fromFile(outFile)
    }
}
