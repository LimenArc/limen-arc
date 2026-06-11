package com.forge.app.packaging

import com.android.apksig.ApkSigner as AndroidApkSigner
import java.io.File
import java.security.cert.X509Certificate

/**
 * Final step: signs the patched, realigned APK using APK Signature Scheme
 * v2 (and v3, where supported) via Google's standalone
 * [apksig](https://android.googlesource.com/platform/tools/apksig/) library
 * - the same code `apksigner` uses, but pure-Java and runnable on-device.
 */
object ApkSigner {

    private const val MIN_SDK = 26

    fun sign(inputApk: File, outputApk: File, identity: SigningIdentity) {
        val signerConfig = AndroidApkSigner.SignerConfig.Builder(
            "forge",
            identity.privateKey,
            listOf(identity.certificate as X509Certificate)
        ).build()

        val signer = AndroidApkSigner.Builder(listOf(signerConfig))
            .setInputApk(inputApk)
            .setOutputApk(outputApk)
            .setV1SigningEnabled(true)
            .setV2SigningEnabled(true)
            .setV3SigningEnabled(true)
            .setMinSdkVersion(MIN_SDK)
            .build()

        signer.sign()
    }
}
