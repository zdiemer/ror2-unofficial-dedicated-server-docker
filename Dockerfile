FROM ubuntu:24.04

ARG PROTON_VERSION=GE-Proton11-7
ARG BEPINEX_VERSION=5.4.23.5

ENV DEBIAN_FRONTEND=noninteractive
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip python3 xvfb xauth \
    libgl1 libgl1:i386 libvulkan1 libvulkan1:i386 mesa-vulkan-drivers \
    libc6:i386 libgcc-s1:i386 libstdc++6:i386 libx11-6 libx11-6:i386 \
    libxcb1 libxcb1:i386 libasound2t64 libasound2t64:i386 \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    mkdir -p /opt/proton /opt/bepinex; \
    base="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_VERSION}"; \
    archive="${PROTON_VERSION}-x86_64.tar.gz"; \
    curl -fL --retry 3 "${base}/${archive}" -o "/tmp/${archive}"; \
    curl -fL --retry 3 "${base}/${PROTON_VERSION}-x86_64.sha512sum" -o /tmp/proton.sha512sum; \
    cd /tmp; sha512sum -c proton.sha512sum; \
    tar -xzf "${archive}" -C /opt/proton; \
    ln -s "/opt/proton/${PROTON_VERSION}" /opt/proton/current; \
    curl -fL --retry 3 "https://github.com/BepInEx/BepInEx/releases/download/v${BEPINEX_VERSION}/BepInEx_win_x64_${BEPINEX_VERSION}.zip" -o /tmp/bepinex-windows.zip; \
    unzip -q /tmp/bepinex-windows.zip -d /opt/bepinex; \
    rm -f "/tmp/${archive}" /tmp/proton.sha512sum /tmp/bepinex-windows.zip

COPY plugin/Ror2UnofficialDedicatedServer.dll /opt/server-plugin/Ror2UnofficialDedicatedServer.dll
COPY prepare.py /opt/prepare.py
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh && mkdir -p /work/home /config /opt/steam && chown -R 1000:1000 /work /config

USER 1000:1000
WORKDIR /work/game
ENV STEAM_COMPAT_DATA_PATH=/work/prefix \
    HOME=/work/home \
    STEAM_COMPAT_CLIENT_INSTALL_PATH=/opt/steam \
    SteamAppId=632360 \
    SteamGameId=632360 \
    PROTON_NO_ESYNC=1 \
    PROTON_NO_FSYNC=1 \
    PROTON_USE_WINED3D=1 \
    LIBGL_ALWAYS_SOFTWARE=1 \
    WINEDLLOVERRIDES=winhttp=n,b
EXPOSE 7777/udp
ENTRYPOINT ["/opt/entrypoint.sh"]
