FROM eclipse-temurin:17-jdk-jammy

# ── Android SDK ────────────────────────────────────────────────────────────────
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/34.0.0

ARG CMDLINE_TOOLS_VERSION=11076708
ARG ANDROID_COMPILE_SDK=35
ARG ANDROID_BUILD_TOOLS=34.0.0

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl unzip wget && \
    rm -rf /var/lib/apt/lists/*

# Install Android command-line tools
RUN mkdir -p "$ANDROID_HOME/cmdline-tools" && \
    curl -fsSL \
      "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip" \
      -o /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d "$ANDROID_HOME/cmdline-tools" && \
    mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest" && \
    rm /tmp/cmdline-tools.zip

# Accept licences and install SDK platform + build-tools
RUN yes | sdkmanager --licenses > /dev/null && \
    sdkmanager \
        "platform-tools" \
        "platforms;android-${ANDROID_COMPILE_SDK}" \
        "build-tools;${ANDROID_BUILD_TOOLS}"

# ── Gradle wrapper jar ─────────────────────────────────────────────────────────
# Use system Gradle (pre-installed in this image via Gradle's own install layer)
ARG GRADLE_VERSION=8.7
RUN curl -fsSL "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" \
        -o /tmp/gradle.zip && \
    unzip -q /tmp/gradle.zip -d /opt && \
    rm /tmp/gradle.zip
ENV PATH=$PATH:/opt/gradle-${GRADLE_VERSION}/bin

# ── Project ───────────────────────────────────────────────────────────────────
WORKDIR /project
COPY . .

# Generate the wrapper jar with the pinned Gradle version
RUN gradle wrapper --gradle-version=${GRADLE_VERSION} --distribution-type=bin && \
    chmod +x gradlew

# Pre-fetch Gradle distribution (warm cache)
RUN ./gradlew --version

# Compile debug APK
RUN ./gradlew assembleDebug --no-daemon

# Default command: copy the APK to a mounted /out directory
CMD ["sh", "-c", \
     "cp app/build/outputs/apk/debug/app-debug.apk /out/limenarcterminal-debug.apk && \
      echo 'APK written to /out/limenarcterminal-debug.apk'"]
