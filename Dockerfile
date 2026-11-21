FROM --platform=linux/arm64 alpine:latest

ARG HOST=github.com
ARG REPO=ildarmaga/wdtt/releases/download
ARG WDTT_VER=v1.5.76

ENV GOMEMLIMIT=120MiB
ENV GOGC=50

RUN apk add --no-cache curl iptables iproute2 ca-certificates unzip && \
    mkdir -p /etc/wdtt-xray && \
    curl -fL -o /usr/local/bin/wdtt-app "https://${HOST}/${REPO}/${WDTT_VER}/wdtt-linux-arm64" && \
    chmod +x /usr/local/bin/wdtt-app && \
    rm -rf /var/cache/apk/* /tmp/*

COPY entrypoint.sh /entrypoint.sh
COPY systemctl /usr/bin/systemctl

RUN sed -i 's/\r$//' /entrypoint.sh /usr/bin/systemctl && \
    chmod +x /entrypoint.sh /usr/bin/systemctl

EXPOSE 2860/tcp 56000/udp 56003/udp 46000/udp

ENTRYPOINT ["/entrypoint.sh"]
