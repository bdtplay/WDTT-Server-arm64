FROM --platform=linux/arm64 alpine:latest

ARG HOST=github.com
ARG REPO=ildarmaga/wdtt/releases/download
ARG WDTT_VER=v1.5.76

RUN apk add --no-cache curl iptables iproute2 ca-certificates && \
    curl -fL -o /usr/local/bin/wdtt-app "https://${HOST}/${REPO}/${WDTT_VER}/wdtt-linux-arm64" && \
    chmod +x /usr/local/bin/wdtt-app

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 2860/tcp 56000/udp 56003/udp 46000/udp

ENTRYPOINT ["/entrypoint.sh"]
