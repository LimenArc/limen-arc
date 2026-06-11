package com.forge.app.packaging

import android.content.Context
import org.bouncycastle.asn1.x500.X500Name
import org.bouncycastle.cert.X509v3CertificateBuilder
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder
import org.bouncycastle.jce.provider.BouncyCastleProvider
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder
import java.io.File
import java.math.BigInteger
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Security
import java.security.cert.X509Certificate
import java.util.Date
import java.util.concurrent.TimeUnit

/** Holds the key/certificate Forge uses to sign every APK it generates. */
data class SigningIdentity(val privateKey: PrivateKey, val certificate: X509Certificate)

/**
 * Generates (once) and reuses a per-user signing identity, stored as a
 * PKCS#12 keystore in the app's private storage
 * (`/data/data/com.forge.app/files/forge_signing.p12`).
 *
 * Reusing the same key for every forged app means:
 *  - a forged app can be "updated" later (re-forged and reinstalled over
 *    itself) without uninstalling first, since Android requires matching
 *    signatures for updates
 *  - all of a user's forged apps are mutually trusted as coming from the
 *    same signer
 *
 * The keystore never leaves the device and is wiped if Forge is
 * uninstalled or its data is cleared - at that point previously-forged apps
 * can no longer be updated in place (they'd need to be uninstalled and
 * re-forged).
 */
object KeystoreManager {

    private const val KEYSTORE_FILE = "forge_signing.p12"
    private const val ALIAS = "forge-user-key"

    // The keystore file lives in the app's private storage (mode 0700,
    // inaccessible to other apps without root), so a static password adds
    // no real protection - it only satisfies the PKCS#12 API's requirement
    // for one. See README "Security model".
    private val PASSWORD = "forge-on-device".toCharArray()

    init {
        if (Security.getProvider("BC") == null) {
            Security.addProvider(BouncyCastleProvider())
        }
    }

    fun getOrCreateSigningIdentity(context: Context): SigningIdentity {
        val file = File(context.filesDir, KEYSTORE_FILE)
        val keyStore = KeyStore.getInstance("PKCS12")

        if (file.exists()) {
            file.inputStream().use { keyStore.load(it, PASSWORD) }
            val key = keyStore.getKey(ALIAS, PASSWORD) as PrivateKey
            val cert = keyStore.getCertificate(ALIAS) as X509Certificate
            return SigningIdentity(key, cert)
        }

        keyStore.load(null, null)
        val identity = generateIdentity()
        keyStore.setKeyEntry(ALIAS, identity.privateKey, PASSWORD, arrayOf(identity.certificate))
        file.outputStream().use { keyStore.store(it, PASSWORD) }
        return identity
    }

    private fun generateIdentity(): SigningIdentity {
        val keyPairGenerator = KeyPairGenerator.getInstance("RSA")
        keyPairGenerator.initialize(2048)
        val keyPair = keyPairGenerator.generateKeyPair()

        val now = Date()
        val notAfter = Date(now.time + TimeUnit.DAYS.toMillis(30L * 365))
        val subject = X500Name("CN=Forge User, O=Forge, OU=Forge On-Device Signing")
        val serial = BigInteger(160, java.security.SecureRandom())

        val certBuilder: X509v3CertificateBuilder = JcaX509v3CertificateBuilder(
            subject, serial, now, notAfter, subject, keyPair.public
        )
        val signer = JcaContentSignerBuilder("SHA256WithRSA").build(keyPair.private)
        val certHolder = certBuilder.build(signer)
        val certificate = JcaX509CertificateConverter().getCertificate(certHolder)

        return SigningIdentity(keyPair.private, certificate)
    }
}
