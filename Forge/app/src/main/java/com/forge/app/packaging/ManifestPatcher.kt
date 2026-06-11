package com.forge.app.packaging

import io.github.reandroid.apk.ApkModule
import io.github.reandroid.arsc.chunk.xml.AndroidManifestBlock
import io.github.reandroid.arsc.chunk.xml.ResXmlAttribute
import io.github.reandroid.arsc.chunk.xml.ResXmlElement
import io.github.reandroid.arsc.value.ValueType
import java.io.File

/** Allowed `android:screenOrientation` choices exposed to the user. */
enum class ForgeOrientation(val attrValue: Int) {
    UNSPECIFIED(-1),
    PORTRAIT(1),
    LANDSCAPE(0),
    SENSOR_PORTRAIT(7),
    SENSOR_LANDSCAPE(6),
    FULL_SENSOR(10),
}

/**
 * Step 2 of the template-injection pipeline: patches the binary
 * `AndroidManifest.xml` (and, where useful, `resources.arsc`) inside an APK
 * using [ARSCLib](https://github.com/REAndroid/ARSCLib) - a pure-Java
 * library with no native/AAPT dependency, so it runs fine on-device.
 *
 * Three things are rewritten:
 *  - the manifest `package` (application ID) - must be unique per forged app
 *  - the application's display label (`android:label`) - rewritten to a raw
 *    string so we don't need to touch the resource table
 *  - the main activity's `android:screenOrientation`
 */
object ManifestPatcher {

    fun patch(
        inputApk: File,
        outputApk: File,
        newPackageName: String,
        newLabel: String,
        orientation: ForgeOrientation
    ) {
        require(PackageNameGenerator.isValid(newPackageName)) {
            "Invalid package name: $newPackageName"
        }

        val apkModule = ApkModule.loadApkFile(inputApk)
        val manifest = apkModule.androidManifestBlock

        manifest.packageName = newPackageName
        renameResourcePackage(apkModule, newPackageName)

        setApplicationLabel(manifest, newLabel)
        setMainActivityOrientation(manifest, orientation)

        manifest.refresh()
        apkModule.writeApk(outputApk)
        apkModule.close()
    }

    private fun setApplicationLabel(manifest: AndroidManifestBlock, label: String) {
        val application = manifest.applicationElement ?: return
        val labelAttr = application.getOrCreateAndroidAttribute("label", AndroidManifestBlock.ID_label)
        // Replace the @string/... reference with a raw string so the new
        // label takes effect without editing resources.arsc.
        labelAttr.setValueAsString(label)
    }

    private fun setMainActivityOrientation(manifest: AndroidManifestBlock, orientation: ForgeOrientation) {
        val application = manifest.applicationElement ?: return
        val activity = findMainActivity(application) ?: return
        val attr = activity.getOrCreateAndroidAttribute("screenOrientation", AndroidManifestBlock.ID_screenOrientation)
        attr.setTypeAndData(ValueType.INT_DEC, orientation.attrValue)
    }

    private fun findMainActivity(application: ResXmlElement): ResXmlElement? {
        val activities = application.listElements().asSequence()
            .filter { it.name == AndroidManifestBlock.TAG_activity }
            .toList()
        if (activities.isEmpty()) return null

        // Prefer the activity with the LAUNCHER intent filter.
        val launcher = activities.firstOrNull { activity ->
            activity.listElements().asSequence().any { intentFilter ->
                intentFilter.name == AndroidManifestBlock.TAG_intent_filter &&
                    intentFilter.listElements().asSequence().any { cat ->
                        cat.name == AndroidManifestBlock.TAG_category &&
                            cat.searchAttributeByResourceId(AndroidManifestBlock.ID_name)
                                ?.valueAsString == AndroidManifestBlock.CATEGORY_LAUNCHER
                    }
            }
        }
        return launcher ?: activities.first()
    }

    /**
     * Renames the resources.arsc package entry to match the new application
     * ID. This is cosmetic (resources are addressed by numeric ID, not by
     * package name) but keeps the APK internally consistent and avoids
     * confusing some inspection tools.
     */
    private fun renameResourcePackage(apkModule: ApkModule, newPackageName: String) {
        if (!apkModule.hasTableBlock()) return
        runCatching {
            val table = apkModule.tableBlock
            for (pkg in table.listPackages()) {
                pkg.name = newPackageName
            }
            table.refresh()
        }
    }

}
