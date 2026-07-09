FROM eclipse-temurin:17-jdk-jammy

# Android SDK
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV CMDLINE_TOOLS_VERSION=11076708
ENV ANDROID_SDK_MANAGER="${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager"

RUN apt-get update && apt-get install -y bash curl unzip git python3 make g++

# Node.js 20 (eclipse-temurin JDK images ship no Node)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    node --version && npm --version

RUN mkdir -p "${ANDROID_SDK_ROOT}/cmdline-tools" && \
    curl -fsSL https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip -o /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d /tmp/ && \
    mv /tmp/cmdline-tools "${ANDROID_SDK_ROOT}/cmdline-tools/latest" && \
    rm /tmp/cmdline-tools.zip

RUN yes | ${ANDROID_SDK_MANAGER} --licenses
RUN test -d "${ANDROID_SDK_ROOT}/licenses"

RUN ${ANDROID_SDK_MANAGER} --install \
    "platforms;android-35" \
    "build-tools;35.0.0" \
    "platform-tools"

ENV GRADLE_VERSION=8.12
RUN curl -fsSL https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -o /tmp/gradle.zip && \
    unzip -q /tmp/gradle.zip -d /opt/ && \
    rm /tmp/gradle.zip
ENV PATH="/opt/gradle-${GRADLE_VERSION}/bin:${PATH}"

RUN npm install -g \
    @ionic/cli@7.2.1 \
    @angular/cli@20 \
    cordova@12 \
    --legacy-peer-deps

RUN npm install -g yarn --legacy-peer-deps 2>/dev/null || true

WORKDIR /app
COPY docker/android-builder/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
