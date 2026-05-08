package com.multimodelchat;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.provider.DocumentsContract;
import android.provider.MediaStore;
import android.provider.Settings;
import android.util.Base64;
import android.util.Log;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.MimeTypeMap;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileFilter;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class MainActivity extends Activity {

    private static final String TAG = "MultiModelChat";
    private static final int REQUEST_FOLDER  = 1001;
    private static final int REQUEST_STORAGE = 1002;
    private static final int REQUEST_FILE    = 1003;
    private static final int REQUEST_PERMS   = 1004;

    private WebView webView;
    private Process serverProcess;
    private final int localPort = 8080;
    private String currentModelName;
    private volatile String lastServerLog = "";
    private Handler mainHandler;

    // For WebChromeClient file chooser (image upload from HTML <input type="file">)
    private ValueCallback<Uri[]> fileChooserCallback;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        setContentView(R.layout.activity_main);

        mainHandler = new Handler(Looper.getMainLooper());
        webView = findViewById(R.id.webview);
        setupWebView();
        webView.addJavascriptInterface(new Bridge(), "Android");
        webView.loadUrl("file:///android_asset/index.html");
    }

    private void setupWebView() {
        WebSettings s = webView.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setAllowFileAccessFromFileURLs(true);
        s.setAllowUniversalAccessFromFileURLs(true);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
        s.setMediaPlaybackRequiresUserGesture(false);

        getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                return false;
            }
        });

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(WebView webView,
                    ValueCallback<Uri[]> filePathCallback,
                    FileChooserParams fileChooserParams) {
                if (fileChooserCallback != null) {
                    fileChooserCallback.onReceiveValue(null);
                }
                fileChooserCallback = filePathCallback;
                Intent intent = fileChooserParams.createIntent();
                try {
                    startActivityForResult(intent, REQUEST_FILE);
                } catch (Exception e) {
                    fileChooserCallback = null;
                    return false;
                }
                return true;
            }
        });
    }

    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) webView.goBack();
        else super.onBackPressed();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        killServer();
        if (webView != null) webView.destroy();
    }

    @Override
    protected void onResume() {
        super.onResume();
        webView.evaluateJavascript("if(typeof onAppResume==='function')onAppResume()", null);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);

        if (requestCode == REQUEST_FILE) {
            Uri[] results = null;
            if (resultCode == RESULT_OK && data != null) {
                String dataStr = data.getDataString();
                if (dataStr != null) {
                    results = new Uri[]{Uri.parse(dataStr)};
                } else if (data.getClipData() != null) {
                    int count = data.getClipData().getItemCount();
                    results = new Uri[count];
                    for (int i = 0; i < count; i++) {
                        results[i] = data.getClipData().getItemAt(i).getUri();
                    }
                }
            }
            if (fileChooserCallback != null) {
                fileChooserCallback.onReceiveValue(results);
                fileChooserCallback = null;
            }
            return;
        }

        if (requestCode == REQUEST_FOLDER && resultCode == RESULT_OK && data != null) {
            String path = uriToPath(data.getData());
            if (path != null) {
                final String safePath = path.replace("\\", "\\\\").replace("'", "\\'");
                webView.evaluateJavascript("onFolderSelected('" + safePath + "')", null);
            } else {
                webView.evaluateJavascript("onFolderSelectFailed()", null);
            }
            return;
        }

        if (requestCode == REQUEST_STORAGE || requestCode == REQUEST_PERMS) {
            webView.evaluateJavascript("onStorageGranted()", null);
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQUEST_PERMS) {
            webView.evaluateJavascript("onStorageGranted()", null);
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private void killServer() {
        if (serverProcess != null) {
            try { serverProcess.destroy(); } catch (Exception ignored) {}
            serverProcess = null;
        }
    }

    private boolean probeServer() {
        try {
            URL url = new URL("http://127.0.0.1:" + localPort + "/health");
            HttpURLConnection c = (HttpURLConnection) url.openConnection();
            c.setConnectTimeout(500);
            c.setReadTimeout(500);
            int code = c.getResponseCode();
            c.disconnect();
            return code == 200;
        } catch (Exception e) {
            return false;
        }
    }

    private String uriToPath(Uri uri) {
        if (uri == null) return null;
        try {
            String docId = DocumentsContract.getTreeDocumentId(uri);
            if (docId != null && docId.startsWith("primary:")) {
                return Environment.getExternalStorageDirectory() + "/" + docId.substring(8);
            }
        } catch (Exception ignored) {}
        return uri.getPath();
    }

    private String readStreamToBase64(InputStream in) throws IOException {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        byte[] buf = new byte[8192];
        int len;
        while ((len = in.read(buf)) != -1) baos.write(buf, 0, len);
        return Base64.encodeToString(baos.toByteArray(), Base64.NO_WRAP);
    }

    // ── Android ↔ WebView Bridge ───────────────────────────────────────────────
    public class Bridge {

        @JavascriptInterface
        public int getLocalPort() { return localPort; }

        @JavascriptInterface
        public String getStatus() {
            if (currentModelName != null && serverProcess != null) {
                try { serverProcess.exitValue(); /* throws if alive */ }
                catch (IllegalThreadStateException e) { return "ready:" + currentModelName; }
            }
            return "needs_model";
        }

        @JavascriptInterface
        public String getDefaultModelsPath() {
            String[] candidates = {
                "/storage/emulated/0/Models",
                "/storage/emulated/0/Download"
            };
            for (String p : candidates) {
                if (new File(p).exists()) return p;
            }
            return "/storage/emulated/0/Download";
        }

        @JavascriptInterface
        public String getModelList(String folder) {
            File dir = new File(folder);
            if (!dir.exists() || !dir.canRead()) return "";
            File[] files = dir.listFiles(f -> f.isFile() && f.getName().toLowerCase().endsWith(".gguf"));
            if (files == null || files.length == 0) return "";
            Arrays.sort(files, (a, b) -> a.getName().compareToIgnoreCase(b.getName()));
            StringBuilder sb = new StringBuilder();
            for (File f : files) {
                if (sb.length() > 0) sb.append('\n');
                sb.append(f.getName()).append('|').append(f.getAbsolutePath());
            }
            return sb.toString();
        }

        @JavascriptInterface
        public boolean pathExists(String path) {
            return new File(path).exists();
        }

        @JavascriptInterface
        public String getStorageStatus() {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                return Environment.isExternalStorageManager() ? "ok" : "needs_all_files";
            }
            return checkSelfPermission(android.Manifest.permission.READ_EXTERNAL_STORAGE)
                == PackageManager.PERMISSION_GRANTED ? "ok" : "needs_request";
        }

        @JavascriptInterface
        public void requestStorageAccess() {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                Intent i = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                    Uri.parse("package:" + getPackageName()));
                startActivityForResult(i, REQUEST_STORAGE);
            } else {
                requestPermissions(
                    new String[]{android.Manifest.permission.READ_EXTERNAL_STORAGE},
                    REQUEST_PERMS);
            }
        }

        @JavascriptInterface
        public void browseFolders() {
            Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
            startActivityForResult(i, REQUEST_FOLDER);
        }

        @JavascriptInterface
        public String findAllGgufFiles() {
            List<String> roots = new ArrayList<>();
            File ext = Environment.getExternalStorageDirectory();
            if (ext != null) roots.add(ext.getAbsolutePath());
            File[] extDirs = getExternalFilesDirs(null);
            if (extDirs != null) {
                for (File d : extDirs) { if (d != null) roots.add(d.getAbsolutePath()); }
            }
            List<File> found = new ArrayList<>();
            for (String root : roots) findGguf(new File(root), found, 0);
            if (found.isEmpty()) return "";
            StringBuilder sb = new StringBuilder();
            for (File f : found) {
                if (sb.length() > 0) sb.append('\n');
                sb.append(f.getName()).append('|').append(f.getAbsolutePath());
            }
            return sb.toString();
        }

        private void findGguf(File dir, List<File> out, int depth) {
            if (depth > 5 || dir == null || !dir.exists() || !dir.canRead()) return;
            File[] files = dir.listFiles();
            if (files == null) return;
            for (File f : files) {
                if (f.isFile() && f.getName().toLowerCase().endsWith(".gguf")) out.add(f);
                else if (f.isDirectory() && !f.getName().startsWith(".")) findGguf(f, out, depth + 1);
            }
        }

        @JavascriptInterface
        public String getLastError() { return lastServerLog; }

        @JavascriptInterface
        public void loadModel(final String modelPath) {
            final String escaped = modelPath.replace("\\", "\\\\").replace("'", "\\'");
            mainHandler.post(() -> webView.evaluateJavascript("onModelLoading('" + escaped + "')", null));

            new Thread(() -> {
                killServer();
                lastServerLog = "";

                String nativeDir = getApplicationInfo().nativeLibraryDir;
                String serverBin = nativeDir + "/libllama_server.so";

                if (!new File(serverBin).exists()) {
                    String err = "Server binary not found at: " + serverBin;
                    lastServerLog = err;
                    mainHandler.post(() -> webView.evaluateJavascript(
                        "onModelError('" + err.replace("'", "\\'") + "')", null));
                    return;
                }

                try {
                    ProcessBuilder pb = new ProcessBuilder(
                        serverBin,
                        "--model",    modelPath,
                        "--host",     "127.0.0.1",
                        "--port",     String.valueOf(localPort),
                        "--ctx-size", "4096",
                        "--mmproj",   findMmproj(modelPath)
                    );
                    pb.environment().put("LD_LIBRARY_PATH", nativeDir);
                    pb.redirectErrorStream(true);
                    serverProcess = pb.start();

                    StringBuilder logBuf = new StringBuilder();
                    new Thread(() -> {
                        try (BufferedReader br = new BufferedReader(
                                new InputStreamReader(serverProcess.getInputStream()))) {
                            String line;
                            while ((line = br.readLine()) != null) {
                                logBuf.append(line).append('\n');
                                lastServerLog = logBuf.toString();
                            }
                        } catch (IOException ignored) {}
                    }).start();

                    // Poll until server ready (up to 2 minutes)
                    long deadline = System.currentTimeMillis() + 120_000;
                    while (System.currentTimeMillis() < deadline) {
                        try { serverProcess.exitValue(); throw new Exception("Server exited early"); }
                        catch (IllegalThreadStateException e) { /* still alive */ }
                        if (probeServer()) {
                            String name = new File(modelPath).getName().replaceAll("\\.gguf$", "");
                            currentModelName = name;
                            mainHandler.post(() -> webView.evaluateJavascript(
                                "onModelReady('" + name.replace("'", "\\'") + "')", null));
                            return;
                        }
                        Thread.sleep(500);
                    }
                    throw new Exception("Server did not start within 2 minutes.");

                } catch (Exception e) {
                    killServer();
                    String err = e.getMessage() != null ? e.getMessage() : "Unknown error";
                    lastServerLog += "\n" + err;
                    mainHandler.post(() -> webView.evaluateJavascript(
                        "onModelError('" + err.replace("'", "\\'") + "')", null));
                }
            }).start();
        }

        // Look for a mmproj file alongside the model (for vision support)
        private String findMmproj(String modelPath) {
            File dir = new File(modelPath).getParentFile();
            if (dir == null) return "";
            File[] mmprojs = dir.listFiles(f -> f.getName().toLowerCase().contains("mmproj") && f.getName().endsWith(".gguf"));
            return (mmprojs != null && mmprojs.length > 0) ? mmprojs[0].getAbsolutePath() : "";
        }

        @JavascriptInterface
        public void changeModel() {
            killServer();
            currentModelName = null;
            mainHandler.post(() -> webView.evaluateJavascript("onShowModelPicker()", null));
        }

        @JavascriptInterface
        public String getStorageRoots() {
            StringBuilder sb = new StringBuilder();
            File[] dirs = getExternalFilesDirs(null);
            if (dirs != null) {
                for (File d : dirs) {
                    if (d != null) { if (sb.length() > 0) sb.append('\n'); sb.append(d.getAbsolutePath()); }
                }
            }
            return sb.toString();
        }

        // Read an image URI (from file chooser) as base64 data URL for the WebView
        @JavascriptInterface
        public String uriToDataUrl(String uriStr) {
            try {
                Uri uri = Uri.parse(uriStr);
                String mime = getContentResolver().getType(uri);
                if (mime == null) mime = "image/jpeg";
                try (InputStream in = getContentResolver().openInputStream(uri)) {
                    if (in == null) return "";
                    String b64 = readStreamToBase64(in);
                    return "data:" + mime + ";base64," + b64;
                }
            } catch (Exception e) {
                Log.e(TAG, "uriToDataUrl: " + e.getMessage());
                return "";
            }
        }
    }
}
