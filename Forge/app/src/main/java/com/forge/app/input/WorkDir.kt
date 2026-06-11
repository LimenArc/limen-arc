package com.forge.app.input

import android.content.Context
import java.io.File
import java.util.UUID

/** Creates a fresh scratch directory under the cache dir for one import. */
object WorkDir {
    fun create(context: Context): File {
        val dir = File(context.cacheDir, "forge_work/${UUID.randomUUID()}/www")
        dir.mkdirs()
        return dir
    }

    /** Wipes any previous import scratch directories. */
    fun clear(context: Context) {
        File(context.cacheDir, "forge_work").deleteRecursively()
    }
}
