# ── Stage 1: Tailwind CSS build ───────────────────────────────────────────────
# Downloads the Tailwind CLI standalone binary and compiles the CSS from the
# HTML source. No Node, no npm — just the ~6MB binary.
FROM alpine:3.19 AS builder

ARG TAILWIND_VERSION=v3.4.4
ARG TARGETOS=linux
ARG TARGETARCH

# Download the correct binary for the build platform
RUN apk add --no-cache curl && \
    ARCH=$(uname -m) && \
    case "$ARCH" in \
      x86_64)  TW_ARCH="x64"   ;; \
      aarch64) TW_ARCH="arm64" ;; \
      armv7l)  TW_ARCH="armv7" ;; \
      *)       TW_ARCH="x64"   ;; \
    esac && \
    curl -fsSL \
      "https://github.com/tailwindlabs/tailwindcss/releases/download/${TAILWIND_VERSION}/tailwindcss-linux-${TW_ARCH}" \
      -o /usr/local/bin/tailwindcss && \
    chmod +x /usr/local/bin/tailwindcss

WORKDIR /build
COPY src/input.css       ./src/input.css
COPY tailwind.config.js  ./tailwind.config.js
COPY index.html          ./index.html

# Scan index.html for used classes and emit a minified CSS bundle
RUN tailwindcss \
      -c tailwind.config.js \
      -i src/input.css \
      -o dist/tailwind.css \
      --minify

# ── Stage 2: nginx runtime ─────────────────────────────────────────────────────
FROM nginx:1.25-alpine

COPY --from=builder /build/dist/tailwind.css /usr/share/nginx/html/tailwind.css
