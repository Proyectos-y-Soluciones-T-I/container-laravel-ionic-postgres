# ─── Stage 1: compile PHP extensions ─────────────────────────────────────────
# Build tools (gcc, g++, make, autoconf) only needed here — NOT in final image.
FROM php:8.1-fpm-alpine AS builder

RUN apk add --no-cache \
    libpng-dev \
    libpq-dev \
    libzip-dev \
    icu-dev \
    oniguruma-dev \
    freetype-dev \
    libjpeg-turbo-dev \
    $PHPIZE_DEPS

RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j$(nproc) \
        pdo \
        pdo_pgsql \
        pgsql \
        gd \
        zip \
        bcmath \
        intl \
        mbstring \
        exif \
        pcntl \
        opcache

RUN pecl install redis-6.1.0 \
    && docker-php-ext-enable redis

# ─── Stage 2: runtime image (no build tools — ~150MB lighter) ─────────────────
FROM php:8.1-fpm-alpine

# Runtime shared libs only — no -dev, no compiler
RUN apk add --no-cache \
    git \
    curl \
    zip \
    unzip \
    bash \
    libpng \
    libpq \
    libzip \
    icu-libs \
    oniguruma \
    freetype \
    libjpeg-turbo

# Copy compiled .so files and their enablement ini files from builder
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

RUN curl -sS https://getcomposer.org/installer | php -- \
    --install-dir=/usr/local/bin \
    --filename=composer \
    --version=2.5.8

COPY docker/php/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /var/www/html

EXPOSE 9000
ENTRYPOINT ["/entrypoint.sh"]
