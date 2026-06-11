package com.forge.template

import android.annotation.SuppressLint
import android.os.Bundle
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * Generic shell activity for every app Forge generates.
 *
 * The behaviour is entirely driven by `assets/forge.json`, which Forge
 * writes (or leaves at its default) when it injects user content into a
 * copy of this template's compiled APK:
 *
 * ```json
 * { "mode": "local" }
 * ```
 * loads `file:///android_asset/www/index.html` (the user's content).
 *
 * ```json
 * { "mode": "url", "url": "https://example.com" }
 * ```
 * loads the given URL directly ("online wrapper" mode).
 */
class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        webView = WebView(this)
        setContentView(webView)

        with(webView.settings) {
            javaScriptEnabled = true
            domStorageEnabled = true
            allowFileAccess = true
            allowContentAccess = true
            // The template only ever needs to read its own bundled assets,
            // so we deliberately do NOT enable allowFileAccessFromFileURLs
            // or allowUniversalAccessFromFileURLs - that would let local
            // file:// pages reach arbitrary device files or other origins.
            cacheMode = WebSettings.LOAD_DEFAULT
            mediaPlaybackRequiresUserGesture = false
            useWideViewPort = true
            loadWithOverviewMode = true
        }

        webView.webViewClient = object : WebViewClient() {
            override fun onReceivedError(
                view: WebView?,
                errorCode: Int,
                description: String?,
                failingUrl: String?
            ) {
                view?.loadDataWithBaseURL(
                    null,
                    OFFLINE_HTML,
                    "text/html",
                    "utf-8",
                    null
                )
            }
        }

        val config = readForgeConfig()
        when (config.optString("mode", "local")) {
            "url" -> {
                val url = config.optString("url")
                if (url.isNotBlank()) {
                    webView.loadUrl(url)
                } else {
                    webView.loadUrl(LOCAL_INDEX)
                }
            }
            else -> webView.loadUrl(LOCAL_INDEX)
        }
    }

    private fun readForgeConfig(): JSONObject {
        return try {
            val text = assets.open("forge.json").use { stream ->
                BufferedReader(InputStreamReader(stream)).readText()
            }
            JSONObject(text)
        } catch (e: Exception) {
            JSONObject()
        }
    }

    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }

    companion object {
        private const val LOCAL_INDEX = "file:///android_asset/www/index.html"
        private const val OFFLINE_HTML = """
            <html><body style="font-family:sans-serif;text-align:center;padding-top:40%;color:#888;">
            <h2>No connection</h2><p>This app needs the internet to load its content.</p>
            </body></html>
        """
    }
}
