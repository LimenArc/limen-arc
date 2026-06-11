package com.forge.app.packaging

import java.security.MessageDigest

/**
 * Generates a unique application ID for each forged app, e.g.
 * `com.forge.gen.a1b2c3d4e5`. Each app needs a distinct package name so
 * Android treats them as separate installs (otherwise installing a second
 * forged app would be rejected as a signature/package collision, or would
 * silently overwrite the first one).
 */
object PackageNameGenerator {

    private const val PREFIX = "com.forge.gen."

    /**
     * [seed] should be something unique per forge run, e.g.
     * "<app name><System.nanoTime()><random UUID>". The hash is hex-encoded
     * and must start with a letter (Java package segments can't start with a
     * digit), so we prefix a fixed letter if needed.
     */
    fun generate(seed: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(seed.toByteArray())
        val hex = digest.joinToString("") { "%02x".format(it) }.take(10)
        val safe = if (hex.first().isDigit()) "g$hex" else hex
        return PREFIX + safe
    }

    /** Validates that [packageName] is a syntactically legal Android application ID. */
    fun isValid(packageName: String): Boolean {
        val segments = packageName.split(".")
        if (segments.size < 2) return false
        return segments.all { segment ->
            segment.isNotEmpty() &&
                segment.first().isLetter() &&
                segment.all { it.isLetterOrDigit() || it == '_' }
        }
    }
}
