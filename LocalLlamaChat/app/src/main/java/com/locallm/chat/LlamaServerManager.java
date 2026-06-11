package com.locallm.chat;

import android.content.Context;
import android.util.Log;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.ServerSocket;
import java.net.URL;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Manages the lifecycle of the bundled llama-server subprocess.
 *
 * Expects a native executable at <nativeLibraryDir>/libllama_server.so
 * (renamed so the APK packager treats it as a JNI lib and extracts it
 * with execute permission). Any other shared libraries it depends on
 * (libggml.so, libggml-cpu.so, libggml-base.so, libllama.so, libmtmd.so,
 * etc.) must also be placed alongside it in jniLibs/arm64-v8a/ -- they
 * will end up in the same nativeLibraryDir, and we set LD_LIBRARY_PATH
 * to that directory so the dynamic linker can find them.
 */
public class LlamaServerManager {

    private static final String TAG = "LlamaServerManager";
    public static final String SERVER_BINARY = "libllama_server.so";

    public interface Listener {
        void onStatusChanged(String status);
        void onLog(String line);
        void onServerReady(int port);
        void onServerStopped(int exitCode);
    }

    private final Context context;
    private final Listener listener;

    private Process process;
    private Thread logThread;
    private int port = -1;
    private volatile String currentModelPath = null;
    private final AtomicBoolean running = new AtomicBoolean(false);

    public LlamaServerManager(Context context, Listener listener) {
        this.context = context.getApplicationContext();
        this.listener = listener;
    }

    public boolean isRunning() {
        return running.get() && process != null && process.isAlive();
    }

    public int getPort() {
        return port;
    }

    public String getCurrentModelPath() {
        return currentModelPath;
    }

    /**
     * Starts (or restarts) llama-server pointed at the given model file.
     * extraArgs lets the caller pass additional flags
     * (e.g. "-ngl", "99", "-c", "4096", "-t", "4").
     */
    public synchronized void start(String modelPath, List<String> extraArgs) {
        stop();

        File modelFile = new File(modelPath);
        if (!modelFile.exists()) {
            listener.onStatusChanged("error: model file not found: " + modelPath);
            return;
        }

        File nativeDir = new File(context.getApplicationInfo().nativeLibraryDir);
        File serverBin = new File(nativeDir, SERVER_BINARY);
        if (!serverBin.exists()) {
            listener.onStatusChanged("error: " + SERVER_BINARY + " not found in " + nativeDir
                    + " -- bundle a compiled llama-server binary (see README)");
            return;
        }

        int chosenPort = findFreePort();
        if (chosenPort < 0) {
            listener.onStatusChanged("error: no free port available");
            return;
        }
        this.port = chosenPort;
        this.currentModelPath = modelPath;

        List<String> cmd = new ArrayList<>();
        cmd.add(serverBin.getAbsolutePath());
        cmd.add("--model");
        cmd.add(modelPath);
        cmd.add("--host");
        cmd.add("127.0.0.1");
        cmd.add("--port");
        cmd.add(String.valueOf(chosenPort));
        // Enable jinja chat-template handling and reasoning_content
        // splitting if this build of llama-server supports them.
        // Older builds will simply reject/ignore unknown flags --
        // if launch fails, remove these from extraArgs in the UI.
        if (extraArgs != null) {
            cmd.addAll(extraArgs);
        }

        Log.i(TAG, "Launching: " + cmd);

        ProcessBuilder pb = new ProcessBuilder(cmd);
        pb.redirectErrorStream(true);
        pb.directory(nativeDir);

        java.util.Map<String, String> env = pb.environment();
        String existingLdPath = env.get("LD_LIBRARY_PATH");
        String ldPath = nativeDir.getAbsolutePath();
        if (existingLdPath != null && !existingLdPath.isEmpty()) {
            ldPath = ldPath + ":" + existingLdPath;
        }
        env.put("LD_LIBRARY_PATH", ldPath);

        listener.onStatusChanged("starting");

        try {
            process = pb.start();
            running.set(true);
        } catch (IOException e) {
            Log.e(TAG, "Failed to start llama-server", e);
            listener.onStatusChanged("error: failed to start: " + e.getMessage());
            running.set(false);
            return;
        }

        final Process p = process;
        logThread = new Thread(() -> {
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(p.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    listener.onLog(line);
                }
            } catch (IOException e) {
                Log.w(TAG, "log reader closed", e);
            }
            int exit = -1;
            try {
                exit = p.waitFor();
            } catch (InterruptedException ignored) {
            }
            running.set(false);
            listener.onServerStopped(exit);
        }, "llama-server-log");
        logThread.setDaemon(true);
        logThread.start();

        // Poll /health until the server is ready (or the process dies).
        Thread healthThread = new Thread(() -> pollHealth(chosenPort), "llama-server-health");
        healthThread.setDaemon(true);
        healthThread.start();
    }

    private void pollHealth(int port) {
        String url = "http://127.0.0.1:" + port + "/health";
        for (int i = 0; i < 600; i++) { // up to 60s
            if (!isRunning()) {
                return;
            }
            try {
                HttpURLConnection conn = (HttpURLConnection) new URL(url).openConnection();
                conn.setConnectTimeout(500);
                conn.setReadTimeout(500);
                conn.setRequestMethod("GET");
                int code = conn.getResponseCode();
                conn.disconnect();
                if (code == 200) {
                    listener.onStatusChanged("ready");
                    listener.onServerReady(port);
                    return;
                }
            } catch (IOException ignored) {
                // not up yet
            }
            try {
                Thread.sleep(100);
            } catch (InterruptedException e) {
                return;
            }
        }
        listener.onStatusChanged("error: server did not become ready in time");
    }

    public synchronized void stop() {
        if (process != null) {
            running.set(false);
            process.destroy();
            try {
                if (!process.waitFor(3, java.util.concurrent.TimeUnit.SECONDS)) {
                    process.destroyForcibly();
                }
            } catch (InterruptedException e) {
                process.destroyForcibly();
            }
            process = null;
        }
        port = -1;
    }

    private int findFreePort() {
        try (ServerSocket socket = new ServerSocket(0)) {
            socket.setReuseAddress(true);
            return socket.getLocalPort();
        } catch (IOException e) {
            return -1;
        }
    }
}
