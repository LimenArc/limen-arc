# LocalLlamaChat

A native Android app (WebView + JS bridge, same pattern as MultiModelChat)
that bundles `llama-server` (from llama.cpp) as a local subprocess and
provides a dark, dense, developer-oriented chat UI for it. Everything
runs on-device over `http://127.0.0.1:<port>` — no network requests leave
the phone.

## Project layout

```
LocalLlamaChat/
  settings.gradle, build.gradle, gradle.properties
  app/
    build.gradle                # package com.locallm.chat, minSdk 26, arm64-v8a only
    src/main/
      AndroidManifest.xml
      java/com/locallm/chat/
        MainActivity.java        # WebView host + JS bridge + SAF model picker
        LlamaServerManager.java  # subprocess lifecycle for llama-server
      assets/
        index.html               # full chat UI (HTML/CSS/JS)
      res/...
      jniLibs/arm64-v8a/         # <-- YOU must put llama-server + its .so deps here
```

## YOU MUST SUPPLY: the compiled llama-server binary

This sandbox has no Android NDK, so `llama-server` could not be compiled
here. You need to build llama.cpp for `arm64-v8a` / Android yourself and
drop the resulting binaries into `app/src/main/jniLibs/arm64-v8a/`.

### Why files go in `jniLibs/` and are named `lib*.so`

Android only extracts files from `jniLibs/<abi>/` to a directory on the
filesystem with **execute permission**
(`ApplicationInfo.nativeLibraryDir`), and only if:
- `app/build.gradle` sets `packagingOptions.jniLibs.useLegacyPackaging = true`
  (already configured), and
- `AndroidManifest.xml` sets `android:extractNativeLibs="true"` (already set).
- The filename matches `lib*.so` (the PackageManager's native lib
  extraction only looks for files matching this pattern).

So:
1. Build `llama-server` for Android arm64 (see below).
2. Rename the executable to **`libllama_server.so`** (it's a normal ELF
   executable, not a shared library — the `.so` extension is just so
   Android's packager extracts it with +x permission).
3. Any shared libraries it dynamically links against (depends on your
   build: `libggml.so`, `libggml-base.so`, `libggml-cpu.so`,
   `libggml-metal.so`/`libggml-vulkan.so` if enabled, `libllama.so`,
   `libmtmd.so` for multimodal, `libcurl.so` if `LLAMA_CURL=ON`, etc.)
   must ALSO be copied into `app/src/main/jniLibs/arm64-v8a/` with their
   normal `lib*.so` names — `LlamaServerManager` sets
   `LD_LIBRARY_PATH` to the native lib directory so the dynamic linker
   finds them all at runtime.

### Recommended build (cross-compile with the Android NDK)

```bash
# from a llama.cpp checkout
cmake -B build-android \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-26 \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_CURL=OFF \
  -DGGML_LLAMAFILE=OFF \
  -DBUILD_SHARED_LIBS=ON

cmake --build build-android --target llama-server -j

# Collect:
#   build-android/bin/llama-server          -> libllama_server.so
#   build-android/bin/libggml*.so           -> as-is
#   build-android/bin/libllama.so           -> as-is
#   (any other lib*.so in build-android/bin)
```

If you only have a static build (`BUILD_SHARED_LIBS=OFF`), `llama-server`
will be a single self-contained binary — just rename it to
`libllama_server.so` and you can skip the extra `.so` files.

For GPU acceleration on-device, add `-DGGML_VULKAN=ON` (or
`-DGGML_OPENCL=ON` depending on your llama.cpp version) and pass
`-ngl <N>` via the "Extra llama-server args" field in the app's Model tab.
CPU-only builds work fine but will be slow for larger models.

## Things in this app that depend on your llama.cpp build/version

The UI is written defensively (it checks for fields before using them),
but functionality differs depending on how `llama-server` was built and
which version you use. Specifically:

1. **`--jinja` flag** (enables proper Jinja2 chat-template rendering and
   `reasoning_content` splitting for models like DeepSeek-R1/Qwen3).
   The app always passes `--jinja` on launch
   (`index.html` -> `launchServer()`). Older llama.cpp builds (pre
   ~April 2024 jinja support) will reject this flag and **fail to
   start**. If your binary is older, edit the "Extra llama-server args"
   field to remove it (the app builds the arg list client-side, so this
   is a one-line change in `launchServer()` in `index.html` if you want
   it removed by default).

2. **`reasoning_content` field** — only emitted by builds with
   `--reasoning-format` / jinja reasoning support (recent llama.cpp). If
   absent, the app falls back to parsing inline `<think>...</think>` tags
   from `delta.content` (handled by `makeThinkSplitter()` in
   `index.html`), which works with any build whose model emits literal
   `<think>` tags (e.g. DeepSeek-R1 distills).

3. **`/props` endpoint fields** — `n_ctx`, `n_vocab`, `chat_template`,
   `bos_token`/`eos_token`, and model metadata layout have changed across
   llama.cpp versions (some put architecture/quantization under
   `model_meta` / `meta` / `general.*` keys, others omit them entirely).
   `renderModelDetails()` in `index.html` tries several known key paths
   and silently skips any field it can't find — it will not crash, but
   some rows in the "Model details" panel may simply not appear on older
   servers.

4. **`timings` object** (per-token/per-request `prompt_n`, `predicted_n`,
   `prompt_per_second`, `predicted_per_second`) is a llama.cpp-specific
   extension. It appears in `/completion` responses on essentially all
   versions, but is **only included in `/v1/chat/completions` streaming
   responses on newer builds**. If your build doesn't send it (and
   doesn't send `usage` via `stream_options.include_usage` either — that
   option itself requires a reasonably recent build), the app falls back
   to a client-side estimate of tokens/sec using wall-clock time and an
   approximate 4-chars-per-token heuristic. For accurate token counts,
   either upgrade llama-server or switch "Streaming endpoint" to
   `/completion` in the Guardrails tab.

5. **`stream_options: { include_usage: true }`** — OpenAI-compatible
   option for getting a final `usage` chunk on `/v1/chat/completions`.
   Older servers ignore unknown fields, so this is safe to send either
   way, but only newer builds will actually return the extra chunk.

6. **GBNF grammar / JSON schema constrained decoding** — the `grammar`
   field works on all versions that support GBNF (essentially all
   reasonably recent ones). `response_format: {type: "json_schema", ...}`
   (OpenAI-style) and the native `json_schema` field are both sent by the
   app for the JSON-schema mode; whichever your build recognizes will be
   honored, the other is ignored.

7. **Model file picker / storage** — the app uses
   `ACTION_OPEN_DOCUMENT` (Storage Access Framework) and copies the
   selected `.gguf` into app-private storage (`getFilesDir()/models/`)
   before launching llama-server, since llama-server needs a real
   filesystem path. For very large models this copy can take a while
   (progress is shown via `onModelCopyProgress`). If you grant the app
   "All files access" (`MANAGE_EXTERNAL_STORAGE`, requested via the
   `requestStoragePermission()` bridge call), you can instead pass a
   direct `/sdcard/...` path to `Android.startServer()` from a custom
   file browser to avoid the copy — this is wired up at the bridge level
   but no file-browser UI is included; only the SAF picker is.

## Building the app

This sandbox has no network access to Google's Maven repo, so the Gradle
build could not be verified end-to-end here. To build:

```bash
cd LocalLlamaChat
gradle assembleDebug   # or open in Android Studio and Run
```

(No `gradlew`/wrapper jar is checked in because it requires downloading
`gradle-wrapper.jar` from `services.gradle.org`, which this sandbox
couldn't reach. Generate it yourself with
`gradle wrapper --gradle-version 8.7` once you have network access, or
just use Android Studio.)

The resulting APK still needs the standard signing/zipalign treatment for
Android 11+ (v2/v3 signature scheme) and 16KB-page-size devices (Android
15+/16) — `app/build.gradle` already sets
`packagingOptions.jniLibs.useLegacyPackaging = true` and
`android:extractNativeLibs="true"` so `.so` files are extracted at install
time; just make sure your release build is signed with APK Signature
Scheme v2+ and zipaligned (Android Studio's release build + signing wizard
handles both automatically).

## How it works at runtime

1. User taps **Pick .gguf** -> SAF picker -> file is copied to
   `getFilesDir()/models/<name>.gguf` -> `onModelPicked` fires in JS.
2. JS calls `Android.startServer(path, argsJson)`.
3. `LlamaServerManager` picks a free TCP port, builds the command line
   (`libllama_server.so --model <path> --host 127.0.0.1 --port <port> -c
   <n_ctx> --jinja ...`), sets `LD_LIBRARY_PATH` to
   `nativeLibraryDir`, and starts the process.
4. A background thread polls `GET /health` until it returns 200, then
   calls `onServerReady(port)` in JS.
5. JS fetches `GET /props` and renders the **Model** tab.
6. Chat messages are sent to `/v1/chat/completions` (or `/completion`,
   selectable in **Guardrails**) with `stream: true` and all sampler
   params from the **Guardrails** tab. The SSE stream is parsed for
   `delta.content` / `delta.reasoning_content` and inline `<think>` tags;
   reasoning is shown in a collapsible block above the answer.
7. After each response, token counts / tokens-per-second / TTFT are shown
   per-message, and the context-usage bar (`used / n_ctx`) updates.
8. All Guardrails settings, the constraint (grammar/JSON schema), stop
   sequences, and the last-used model path persist in `localStorage`.
