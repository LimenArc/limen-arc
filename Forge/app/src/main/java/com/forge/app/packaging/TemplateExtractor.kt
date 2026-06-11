package com.forge.app.packaging

import android.content.Context
import com.forge.app.R
import java.io.File

/** Copies the embedded `res/raw/template.apk` into private storage so it can be edited as a zip. */
object TemplateExtractor {

    fun extract(context: Context, destination: File) {
        context.resources.openRawResource(R.raw.template).use { input ->
            destination.outputStream().use { output -> input.copyTo(output) }
        }
    }
}
