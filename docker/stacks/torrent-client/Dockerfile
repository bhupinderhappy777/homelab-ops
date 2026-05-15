FROM ubuntu:22.04

RUN apt update && apt install -y transmission-daemon clamav-daemon && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1002 -G users adminuser

RUN mkdir -p /downloads /home/adminuser/.config/transmission && chown -R adminuser:adminuser /home/adminuser/.config

RUN printf '{"rpc-authentication-required":true,"rpc-username":"admin","rpc-password":"adminadmin","download-dir":"/downloads","rpc-port":9091,"rpc-bind-address":"0.0.0.0","peer-port":6882,"rpc-enabled":true,"rpc-whitelist-enabled":false}' > /home/adminuser/.config/transmission/settings.json && \
    chown adminuser:adminuser /home/adminuser/.config/transmission/settings.json

COPY --chown=1002:1002 entry.sh /entry.sh
RUN chmod +x /entry.sh && chown 1002:1002 /entry.sh

EXPOSE 6882/tcp 9091/tcp
WORKDIR /downloads
USER 1002
ENTRYPOINT ["/entry.sh"]
