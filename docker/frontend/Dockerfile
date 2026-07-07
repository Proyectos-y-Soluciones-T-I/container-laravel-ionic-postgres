FROM node:20.19-alpine

RUN apk add --no-cache git python3 make g++ vips-dev fftw-dev unzip

RUN npm install -g \
    @ionic/cli@7.2.1 \
    @angular/cli@20 \
    --legacy-peer-deps

WORKDIR /app

COPY docker/frontend/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 4200
ENTRYPOINT ["/entrypoint.sh"]
