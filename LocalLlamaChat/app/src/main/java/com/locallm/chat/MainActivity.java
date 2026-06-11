package com.locallm.chat;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.OpenableColumns;
import android.util.Log;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import androidx.appcompat.app.AppCompatActivity;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;

public class MainActivity extends AppCompatActivity implements LlamaServerManager.Listener {

    private static final String TAG = "MainActivity";
    private static final int REQ_PICK_MODEL = 1001;
    private static final int REQ_MANAGE_STORAGE = 1002;

    private WebView webView;
    private LlamaServerManager serverManager;
    private SharedPreferences prefs;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        prefs = getSharedPreferences("locallm", MODE_PRIVATE);
        serverManager = new LlamaServerManager(this, this);

        webView = findViewById(R.id.webview);
        WebSettings ws = webView.getSettings();
        ws.setJavaScriptEnabled(true);
        ws.setDomStorageEnabled(true);
        ws.setDatabaseEnabled(true);
        ws.setAllowFileAccess(true);
        ws.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
        ws.setCacheMode(WebSettings.LOAD_NO_CACHE);

        webView.setWebViewClient(new WebViewClient());
        webView.setWebChromeClient(new WebChromeClient());
        webView.addJavascriptInterface(new Bridge(), "Android");

        webView.loadUrl("file:///android_asset/index.html");
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        serverManager.stop();
    }

    // ---------------------------------------------------------------
    // LlamaServerManager.Listener -> forward to JS
    // ---------------------------------------------------------------

    @Override
    public void onStatusChanged(String status) {
        runOnUiThread(() -> evalJs("onServerStatus", status));
    }

    @Override
    public void onLog(String line) {
        runOnUiThread(() -> evalJs("onServerLog", line));
    }

    @Override
    public void onServerReady(int port) {
        runOnUiThread(() -> evalJs("onServerReady", String.valueOf(port)));
    }

    @Override
    public void onServerStopped(int exitCode) {
        runOnUiThread(() -> evalJs("onServerStopped", String.valueOf(exitCode)));
    }

    private void evalJs(String fn, String arg) {
        String json = JSONObject.quote(arg);
        webView.evaluateJavascript("javascript:window." + fn + " && window." + fn + "(" + json + ")", null);
    }

    // ---------------------------------------------------------------
    // JS bridge
    // ---------------------------------------------------------------

    public class Bridge {

        @JavascriptInterface
        public String getStatus() {
            JSONObject o = new JSONObject();
            try {
                o.put("running", serverManager.isRunning());
                o.put("port", serverManager.getPort());
                o.put("modelPath", serverManager.getCurrentModelPath());
            } catch (JSONException ignored) {
            }
            return o.toString();
        }

        @JavascriptInterface
        public int getPort() {
            return serverManager.getPort();
        }

        /**
         * Launches/relaunches llama-server.
         * argsJson: JSON array of extra CLI args, e.g. ["-c","4096","-ngl","99","-t","4"]
         */
        @JavascriptInterface
        public void startServer(String modelPath, String argsJson) {
            List<String> extra = new ArrayList<>();
            try {
                org.json.JSONArray arr = new org.json.JSONArray(argsJson);
                for (int i = 0; i < arr.length(); i++) {
                    extra.add(arr.getString(i));
                }
            } catch (JSONException e) {
                Log.w(TAG, "bad argsJson", e);
            }
            serverManager.start(modelPath, extra);
        }

        @JavascriptInterface
        public void stopServer() {
            serverManager.stop();
        }

        /** Opens the system file picker filtered to .gguf files (best-effort MIME). */
        @JavascriptInterface
        public void pickModel() {
            Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType("*/*");
            intent.putExtra(Intent.EXTRA_MIME_TYPES, new String[]{"application/octet-stream"});
            try {
                startActivityForResult(Intent.createChooser(intent, "Select a .gguf model"), REQ_PICK_MODEL);
            } catch (Exception e) {
                Log.e(TAG, "pickModel failed", e);
            }
        }

        /** Requests MANAGE_EXTERNAL_STORAGE so /sdcard paths can be used directly without copying. */
        @JavascriptInterface
        public void requestStoragePermission() {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                if (!Environment.isExternalStorageManager()) {
                    Intent intent = new Intent(android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION);
                    intent.setData(Uri.parse("package:" + getPackageName()));
                    startActivityForResult(intent, REQ_MANAGE_STORAGE);
                }
            }
        }

        @JavascriptInterface
        public boolean hasStoragePermission() {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                return Environment.isExternalStorageManager();
            }
            return true;
        }

        @JavascriptInterface
        public String getSavedSetting(String key) {
            return prefs.getString(key, "");
        }

        @JavascriptInterface
        public void saveSetting(String key, String value) {
            prefs.edit().putString(key, value).apply();
        }
    }

    // ---------------------------------------------------------------
    // SAF result -> copy picked .gguf into app-private storage
    // (model files can be multiple GB; copying is slow but guarantees
    // a stable filesystem path llama-server can open(). If the user
    // grants MANAGE_EXTERNAL_STORAGE, prefer passing a direct /sdcard
    // path from a custom file browser instead of copying.)
    // ---------------------------------------------------------------

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQ_PICK_MODEL && resultCode == Activity.RESULT_OK && data != null) {
            Uri uri = data.getData();
            if (uri == null) return;
            try {
                getContentResolver().takePersistableUriPermission(uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION);
            } catch (SecurityException ignored) {
            }
            new Thread(() -> {
                String path = copyUriToModelsDir(uri);
                if (path != null) {
                    runOnUiThread(() -> evalJs("onModelPicked", path));
                } else {
                    runOnUiThread(() -> evalJs("onModelPickError", "failed to read selected file"));
                }
            }).start();
        } else if (requestCode == REQ_MANAGE_STORAGE) {
            runOnUiThread(() -> evalJs("onStoragePermissionResult",
                    String.valueOf(Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
                            && Environment.isExternalStorageManager())));
        }
    }

    private String queryDisplayName(Uri uri) {
        String name = "model.gguf";
        try (android.database.Cursor cursor = getContentResolver().query(uri, null, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                int idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (idx >= 0) {
                    name = cursor.getString(idx);
                }
            }
        } catch (Exception ignored) {
        }
        return name;
    }

    private String copyUriToModelsDir(Uri uri) {
        String name = queryDisplayName(uri);
        File modelsDir = new File(getFilesDir(), "models");
        if (!modelsDir.exists()) modelsDir.mkdirs();
        File outFile = new File(modelsDir, name);
        try (InputStream in = getContentResolver().openInputStream(uri);
             OutputStream out = new FileOutputStream(outFile)) {
            if (in == null) return null;
            byte[] buf = new byte[1 << 20];
            int n;
            long total = 0;
            while ((n = in.read(buf)) > 0) {
                out.write(buf, 0, n);
                total += n;
                final long t = total;
                runOnUiThread(() -> evalJs("onModelCopyProgress", String.valueOf(t)));
            }
            return outFile.getAbsolutePath();
        } catch (Exception e) {
            Log.e(TAG, "copyUriToModelsDir failed", e);
            return null;
        }
    }
}
