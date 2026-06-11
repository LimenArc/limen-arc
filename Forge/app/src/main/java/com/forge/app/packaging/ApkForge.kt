package com.forge.app.packaging

import android.content.Context
import android.graphics.Bitmap
import com.forge.app.data.ContentMode
import com.forge.app.data.ProcessedContent
import com.forge.app.output.OutputWriter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import org.json.JSONObject
import java.io.File
import java.util.UUID

/**
 * Orchestrates the full template-injection pipeline:
 * extract template -> inject content -> patch manifest/resources -> patch
 * icon -> realign -> sign -> write to Downloads/Forge.
 *
 * Emits [ForgeStage] updates as it progresses; the last value is either
 * [ForgeStage.Done] or [ForgeStage.Error].
 */
object ApkForge {

    fun forge(
        context: Context,
        content: ProcessedContent,
        appName: String,
        icon: Bitmap,
        orientation: ForgeOrientation
    ) = flow {
        val workDir = File(context.cacheDir, "forge_build/${UUID.randomUUID()}")
        try {
            workDir.mkdirs()

            val templateApk = File(workDir, "template.apk")
            TemplateExtractor.extract(context, templateApk)

            emit(ForgeStage.Injecting)
            val injectedApk = File(workDir, "injected.apk")
            val forgeConfig = buildForgeConfig(content)
            ZipContentInjector.inject(templateApk, injectedApk, content.wwwDir, forgeConfig)

            emit(ForgeStage.Patching)
            val packageName = PackageNameGenerator.generate(
                "$appName-${System.nanoTime()}-${UUID.randomUUID()}"
            )
            val patchedApk = File(workDir, "patched.apk")
            ManifestPatcher.patch(injectedApk, patchedApk, packageName, appName, orientation)

            emit(ForgeStage.PatchingIcon)
            val iconedApk = File(workDir, "iconed.apk")
            IconPatcher.patch(patchedApk, iconedApk, icon)

            emit(ForgeStage.Aligning)
            val alignedApk = File(workDir, "aligned.apk")
            ApkRealigner.realign(iconedApk, alignedApk)

            emit(ForgeStage.Signing)
            val signedApk = File(workDir, "signed.apk")
            val identity = KeystoreManager.getOrCreateSigningIdentity(context)
            ApkSigner.sign(alignedApk, signedApk, identity)

            emit(ForgeStage.WritingOutput)
            val outputUri = OutputWriter.writeToDownloads(context, signedApk, "${sanitizeFileName(appName)}.apk")

            emit(ForgeStage.Done(outputUri, packageName, appName))
        } catch (e: Exception) {
            emit(ForgeStage.Error(e.message ?: e.javaClass.simpleName, e))
        } finally {
            workDir.deleteRecursively()
        }
    }.flowOn(Dispatchers.Default)

    private fun buildForgeConfig(content: ProcessedContent): String {
        val json = JSONObject()
        when (content.mode) {
            ContentMode.LOCAL -> json.put("mode", "local")
            ContentMode.URL -> {
                json.put("mode", "url")
                json.put("url", content.url)
            }
        }
        return json.toString()
    }

    private fun sanitizeFileName(name: String): String {
        val cleaned = name.trim().replace(Regex("[^A-Za-z0-9._ -]"), "_")
        return cleaned.ifBlank { "ForgedApp" }
    }
}
