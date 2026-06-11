package com.forge.app.output

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File

/** Helpers for installing or sharing a forged APK, and for the "unknown apps" permission flow. */
object InstallLauncher {

    /** True if Forge is allowed to prompt the package installer directly. */
    fun canRequestInstalls(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    /** Settings screen where the user grants "install unknown apps" for Forge. */
    fun unknownAppsSettingsIntent(context: Context): Intent {
        return Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${context.packageName}"))
    }

    /** Builds an ACTION_VIEW intent that opens the system package installer for [apkUri]. */
    fun installIntent(context: Context, apkUri: Uri): Intent {
        val contentUri = toContentUri(context, apkUri)
        return Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(contentUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
    }

    /** Builds a share sheet intent for [apkUri]. */
    fun shareIntent(context: Context, apkUri: Uri): Intent {
        val contentUri = toContentUri(context, apkUri)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "application/vnd.android.package-archive"
            putExtra(Intent.EXTRA_STREAM, contentUri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return Intent.createChooser(send, "Share APK")
    }

    private fun toContentUri(context: Context, uri: Uri): Uri {
        if (uri.scheme == "content") return uri
        val file = File(uri.path ?: error("Invalid output file path"))
        return FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
    }
}
