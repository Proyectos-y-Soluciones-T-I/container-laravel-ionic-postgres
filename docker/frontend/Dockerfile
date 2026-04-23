FROM node:18.16.1-alpine

RUN apk add --no-cache git python3 make g++ vips-dev fftw-dev

RUN npm install -g \
    @ionic/cli@7 \
    @angular/cli@17 \
    --legacy-peer-deps

WORKDIR /app

COPY docker/frontend/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 4200
ENTRYPOINT ["/entrypoint.sh"]
