FROM --platform=linux/arm64 alpine:latest

ARG HOST=github.com
ARG REPO=ildarmaga/wdtt/releases/download
ARG WDTT_VER=v1.5.76
ARG XRAY_REPO=XTLS/Xray-core/releases/latest/download

ENV GOMEMLIMIT=120MiB
ENV GOGC=50

RUN apk add --no-cache curl iptables iproute2 ca-certificates unzip darkhttpd && \
    mkdir -p /etc/wdtt-xray /var/log/wdtt-xray /usr/local/wdtt-xray/bin && \
    curl -fL -o /usr/local/bin/wdtt-app "https://${HOST}/${REPO}/${WDTT_VER}/wdtt-linux-arm64" && \
    chmod +x /usr/local/bin/wdtt-app && \
    curl -fL -o /tmp/xray.zip "https://${HOST}/${XRAY_REPO}/Xray-linux-arm64-v8a.zip" && \
    unzip -o /tmp/xray.zip -d /usr/local/wdtt-xray/bin/ && \
    chmod +x /usr/local/wdtt-xray/bin/xray && \
    ln -sf /usr/local/wdtt-xray/bin/xray /usr/local/bin/xray && \
    ln -sf /usr/local/wdtt-xray/bin/xray /usr/local/wdtt-xray/bin/xray-linux-amd64 && \
    rm -rf /var/cache/apk/* /tmp/*

COPY entrypoint.sh /entrypoint.sh
COPY systemctl /usr/bin/systemctl

RUN sed -i 's/\r$//' /entrypoint.sh /usr/bin/systemctl && \
    chmod +x /entrypoint.sh /usr/bin/systemctl

EXPOSE 80/tcp 2860/tcp 56000/udp 56003/udp 46000/udp

ENTRYPOINT ["/entrypoint.sh"]
