package com.forge.app.packaging

import android.net.Uri

/** Progress states surfaced to the UI while an APK is being forged. */
sealed class ForgeStage {
    data object Injecting : ForgeStage()
    data object Patching : ForgeStage()
    data object PatchingIcon : ForgeStage()
    data object Aligning : ForgeStage()
    data object Signing : ForgeStage()
    data object WritingOutput : ForgeStage()
    data class Done(val outputUri: Uri, val packageName: String, val displayName: String) : ForgeStage()
    data class Error(val message: String, val cause: Throwable? = null) : ForgeStage()
}
