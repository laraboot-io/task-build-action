FROM golang:1.16.2-alpine3.13 AS build
WORKDIR /src
COPY . .
RUN apk upgrade -U -a && \
    apk add wget ca-certificates openssl-dev --update-cache && \
    update-ca-certificates
RUN go get github.com/markbates/pkger/cmd/pkger
RUN apk add bash jq yq curl && \
    wget -4 https://github.com/mikefarah/yq/releases/download/v4.2.0/yq_linux_amd64 -O /usr/bin/yq && \
    chmod +x /usr/bin/yq && \
    (curl -sSL "https://github.com/buildpacks/pack/releases/download/v0.17.0/pack-v0.17.0-linux.tgz" | tar -C /usr/local/bin/ --no-same-owner -xzv pack)
RUN apk add --no-cache gcc musl-dev
RUN wget -4 https://github.com/paketo-buildpacks/packit/releases/download/v0.8.0/jam-linux -O /usr/bin/jam && \
    chmod +x /usr/bin/jam
RUN chmod +x entrypoint.sh && \
    chmod +x ./scripts/build.sh && \
    chmod +x ./scripts/main.sh && \
    mkdir -p dist/bin
VOLUME /src
ENTRYPOINT ["/src/entrypoint.sh"]