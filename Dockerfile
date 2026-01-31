# syntax=docker/dockerfile:1.4
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Supported base images: Ubuntu 24.04, 22.04, 20.04
ARG DISTRIB_IMAGE=ubuntu
ARG DISTRIB_RELEASE=24.04
FROM ${DISTRIB_IMAGE}:${DISTRIB_RELEASE}
ARG DISTRIB_IMAGE
ARG DISTRIB_RELEASE

LABEL maintainer="https://github.com/ehfd,https://github.com/danisla"

ARG DEBIAN_FRONTEND=noninteractive
# Configure rootless user environment for constrained conditions without escalated root privileges inside containers
ARG TZ=UTC
ENV PASSWD=mypasswd
RUN apt-get clean && apt-get update && apt-get dist-upgrade -y && apt-get install --no-install-recommends -y \
        apt-utils \
        dbus-user-session \
        fakeroot \
        fuse \
        kmod \
        locales \
        ssl-cert \
        sudo \
        udev \
        tzdata && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/* && \
    locale-gen en_US.UTF-8 && \
    ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime && echo "${TZ}" > /etc/timezone && \
    # Only use sudo-root for root-owned directory (/dev, /proc, /sys) or user/group permission operations, not for apt-get installation or file/directory operations
    mv -f /usr/bin/sudo /usr/bin/sudo-root && \
    ln -snf /usr/bin/fakeroot /usr/bin/sudo && \
    groupadd -g 1000 ubuntu || echo 'Failed to add ubuntu group' && \
    useradd -ms /bin/bash ubuntu -u 1000 -g 1000 || echo 'Failed to add ubuntu user' && \
    usermod -a -G adm,audio,cdrom,dialout,dip,fax,floppy,games,input,lp,plugdev,render,ssl-cert,sudo,tape,tty,video,voice ubuntu && \
    echo "ubuntu ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    echo "ubuntu:${PASSWD}" | chpasswd && \
    chown -R -f -h --no-preserve-root ubuntu:ubuntu / || echo 'Failed to set filesystem ownership in some paths to ubuntu user' && \
    # Preserve setuid/setgid removed by chown
    chmod -f 4755 /usr/lib/dbus-1.0/dbus-daemon-launch-helper /usr/bin/chfn /usr/bin/chsh /usr/bin/mount /usr/bin/gpasswd /usr/bin/passwd /usr/bin/newgrp /usr/bin/umount /usr/bin/su /usr/bin/sudo-root /usr/bin/fusermount || echo 'Failed to set chmod setuid for some paths' && \
    chmod -f 2755 /var/local /var/mail /usr/sbin/unix_chkpwd /usr/sbin/pam_extrausers_chkpwd /usr/bin/expiry /usr/bin/chage || echo 'Failed to set chmod setgid for some paths'

# Set locales
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"
ENV CURL_RETRY_OPTS="--retry 5 --retry-delay 3 --retry-connrefused"

USER 1000
# Use BUILDAH_FORMAT=docker in buildah
SHELL ["/usr/bin/fakeroot", "--", "/bin/sh", "-c"]

# Install operating system libraries or packages
RUN apt-get update && apt-get install --no-install-recommends -y \
        # Operating system packages
        software-properties-common \
        build-essential \
        ca-certificates \
        alsa-base \
        alsa-utils \
        file \
        gnupg \
        curl \
        wget \
        bzip2 \
        gzip \
        xz-utils \
        unar \
        rar \
        unrar \
        zip \
        unzip \
        zstd \
        gcc \
        git \
        dnsutils \
        jq \
        python3 \
        python3-numpy \
        nano \
        vim \
        htop \
        fonts-dejavu \
        fonts-freefont-ttf \
        fonts-hack \
        fonts-liberation \
        fonts-noto \
        fonts-noto-cjk \
        fonts-noto-cjk-extra \
        fonts-noto-extra \
        fonts-noto-ui-extra \
        fonts-noto-hinted \
        fonts-noto-mono \
        fonts-noto-unhinted \
        fonts-opensymbol \
        fonts-ubuntu \
        lame \
        less \
        libavcodec-extra \
        libpulse0 \
        supervisor \
        net-tools \
        packagekit-tools \
        pkg-config \
        mesa-utils \
        mesa-va-drivers \
        libva2 \
        vainfo \
        vdpau-driver-all \
        libvdpau-va-gl1 \
        vdpauinfo \
        mesa-vulkan-drivers \
        vulkan-tools \
        radeontop \
        libvulkan-dev \
        ocl-icd-libopencl1 \
        clinfo \
        xkb-data \
        xauth \
        xbitmaps \
        xdg-user-dirs \
        xdg-utils \
        xfonts-base \
        xfonts-scalable \
        xinit \
        xsettingsd \
        libxrandr-dev \
        x11-xkb-utils \
        x11-xserver-utils \
        x11-utils \
        x11-apps \
        xserver-xorg-input-all \
        xserver-xorg-video-all \
        xserver-xorg-video-qxl \
        # NVIDIA driver installer dependencies
        libc6-dev \
        libpci3 \
        libelf-dev \
        libglvnd-dev \
        # OpenGL libraries
        libxau6 \
        libxdmcp6 \
        libxcb1 \
        libxext6 \
        libx11-6 \
        libxv1 \
        libxtst6 \
        libdrm2 \
        libegl1 \
        libgl1 \
        libopengl0 \
        libgles1 \
        libgles2 \
        libglvnd0 \
        libglx0 \
        libglu1 \
        libsm6 \
        netcat-openbsd && \
    rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/* || true && \
    # PipeWire and WirePlumber
    mkdir -pm755 /etc/apt/trusted.gpg.d && curl -fsSL ${CURL_RETRY_OPTS} "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xFC43B7352BCC0EC8AF2EEB8B25088A0359807596" | gpg --dearmor -o /etc/apt/trusted.gpg.d/pipewire-debian-ubuntu-pipewire-upstream.gpg && \
    mkdir -pm755 /etc/apt/sources.list.d && echo "deb https://ppa.launchpadcontent.net/pipewire-debian/pipewire-upstream/ubuntu $(grep '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 | tr -d '\"') main" > "/etc/apt/sources.list.d/pipewire-debian-ubuntu-pipewire-upstream-$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 | tr -d '\"').list" && \
    mkdir -pm755 /etc/apt/sources.list.d && echo "deb https://ppa.launchpadcontent.net/pipewire-debian/wireplumber-upstream/ubuntu $(grep '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 | tr -d '\"') main" > "/etc/apt/sources.list.d/pipewire-debian-ubuntu-wireplumber-upstream-$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 | tr -d '\"').list" && \
    apt-get update && apt-get install --no-install-recommends -y \
        pipewire \
        pipewire-alsa \
        pipewire-audio-client-libraries \
        pipewire-jack \
        pipewire-locales \
        pipewire-v4l2 \
        pipewire-vulkan \
        pipewire-libcamera \
        gstreamer1.0-libcamera \
        gstreamer1.0-pipewire \
        libpipewire-0.3-modules \
        libpipewire-module-x11-bell \
        libspa-0.2-bluetooth \
        libspa-0.2-jack \
        libspa-0.2-modules \
        wireplumber \
        wireplumber-locales \
        gir1.2-wp-0.5 && \
    # Packages only meant for x86_64
    if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
    dpkg --add-architecture i386 && apt-get update && apt-get install --no-install-recommends -y \
        nvtop \
        libva2:i386 \
        vdpau-driver-all:i386 \
        mesa-vulkan-drivers:i386 \
        libvulkan-dev:i386 \
        libc6:i386 \
        libxau6:i386 \
        libxdmcp6:i386 \
        libxcb1:i386 \
        libxext6:i386 \
        libx11-6:i386 \
        libxv1:i386 \
        libxtst6:i386 \
        libdrm2:i386 \
        libegl1:i386 \
        libgl1:i386 \
        libopengl0:i386 \
        libgles1:i386 \
        libgles2:i386 \
        libglvnd0:i386 \
        libglx0:i386 \
        libglu1:i386 \
        libsm6:i386; fi && \
    # Install nvidia-vaapi-driver, requires the kernel parameter `nvidia_drm.modeset=1` set to run correctly
    if [ "$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '\"')" \> "20.04" ]; then \
    apt-get update && apt-get install --no-install-recommends -y \
        meson \
        gstreamer1.0-plugins-bad \
        libffmpeg-nvenc-dev \
        libva-dev \
        libegl-dev \
        libgstreamer-plugins-bad1.0-dev && \
    NVIDIA_VAAPI_DRIVER_VERSION="$(curl -fsSL ${CURL_RETRY_OPTS} "https://api.github.com/repos/elFarto/nvidia-vaapi-driver/releases/latest" | jq -r '.tag_name' | sed 's/[^0-9\.\-]*//g')" && \
    cd /tmp && curl -fsSL ${CURL_RETRY_OPTS} "https://github.com/elFarto/nvidia-vaapi-driver/archive/v${NVIDIA_VAAPI_DRIVER_VERSION}.tar.gz" | tar -xzf - && mv -f nvidia-vaapi-driver* nvidia-vaapi-driver && cd nvidia-vaapi-driver && meson setup build && meson install -C build && rm -rf /tmp/*; fi && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/* && \
    echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf && \
    echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf && \
    # Configure OpenCL manually
    mkdir -pm755 /etc/OpenCL/vendors && echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd && \
    # Configure Vulkan manually
    VULKAN_API_VERSION=$(dpkg -s libvulkan1 | grep -oP 'Version: [0-9|\.]+' | grep -oP '[0-9]+(\.[0-9]+)(\.[0-9]+)') && \
    mkdir -pm755 /etc/vulkan/icd.d/ && echo "{\n\
    \"file_format_version\" : \"1.0.0\",\n\
    \"ICD\": {\n\
        \"library_path\": \"libGLX_nvidia.so.0\",\n\
        \"api_version\" : \"${VULKAN_API_VERSION}\"\n\
    }\n\
}" > /etc/vulkan/icd.d/nvidia_icd.json && \
    # Configure EGL manually
    mkdir -pm755 /usr/share/glvnd/egl_vendor.d/ && echo "{\n\
    \"file_format_version\" : \"1.0.0\",\n\
    \"ICD\": {\n\
        \"library_path\": \"libEGL_nvidia.so.0\"\n\
    }\n\
}" > /usr/share/glvnd/egl_vendor.d/10_nvidia.json
# Expose NVIDIA libraries and paths
ENV PATH="/usr/local/nvidia/bin${PATH:+:${PATH}}"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+${LD_LIBRARY_PATH}:}/usr/local/nvidia/lib:/usr/local/nvidia/lib64"
# Make all NVIDIA GPUs visible by default
ENV NVIDIA_VISIBLE_DEVICES=all
# All NVIDIA driver capabilities should preferably be used, check `NVIDIA_DRIVER_CAPABILITIES` inside the container if things do not work
ENV NVIDIA_DRIVER_CAPABILITIES=all
# Disable VSYNC for NVIDIA GPUs
ENV __GL_SYNC_TO_VBLANK=0
# Set default DISPLAY environment
ENV DISPLAY=":20"

# Anything above this line should always be kept the same between docker-selkies-glx-desktop and docker-selkies-egl-desktop

# Default environment variables (default password is "mypasswd")
ENV DISPLAY_SIZEW=1920
ENV DISPLAY_SIZEH=1080
ENV DISPLAY_REFRESH=60
ENV DISPLAY_DPI=96
ENV DISPLAY_CDEPTH=24
ENV VGL_DISPLAY=egl
ENV SELKIES_ENCODER=nvh264enc
ENV SELKIES_ENABLE_RESIZE=false
ENV SELKIES_ENABLE_BASIC_AUTH=true

# Install Xvfb
RUN apt-get update && apt-get install --no-install-recommends -y \
        xvfb && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*

# Install VirtualGL and make libraries available for preload
RUN cd /tmp && VIRTUALGL_VERSION="$(curl -fsSL ${CURL_RETRY_OPTS} "https://api.github.com/repos/VirtualGL/virtualgl/releases/latest" | jq -r '.tag_name' | sed 's/[^0-9\.\-]*//g')" && \
    if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
    dpkg --add-architecture i386 && \
    curl -fsSL ${CURL_RETRY_OPTS} -O "https://github.com/VirtualGL/virtualgl/releases/download/${VIRTUALGL_VERSION}/virtualgl_${VIRTUALGL_VERSION}_amd64.deb" && \
    curl -fsSL ${CURL_RETRY_OPTS} -O "https://github.com/VirtualGL/virtualgl/releases/download/${VIRTUALGL_VERSION}/virtualgl32_${VIRTUALGL_VERSION}_amd64.deb" && \
    apt-get update && apt-get install -y --no-install-recommends "./virtualgl_${VIRTUALGL_VERSION}_amd64.deb" "./virtualgl32_${VIRTUALGL_VERSION}_amd64.deb" && \
    rm -f "virtualgl_${VIRTUALGL_VERSION}_amd64.deb" "virtualgl32_${VIRTUALGL_VERSION}_amd64.deb" && \
    chmod -f u+s /usr/lib/libvglfaker.so /usr/lib/libvglfaker-nodl.so /usr/lib/libvglfaker-opencl.so /usr/lib/libdlfaker.so /usr/lib/libgefaker.so && \
    chmod -f u+s /usr/lib32/libvglfaker.so /usr/lib32/libvglfaker-nodl.so /usr/lib32/libvglfaker-opencl.so /usr/lib32/libdlfaker.so /usr/lib32/libgefaker.so && \
    chmod -f u+s /usr/lib/i386-linux-gnu/libvglfaker.so /usr/lib/i386-linux-gnu/libvglfaker-nodl.so /usr/lib/i386-linux-gnu/libvglfaker-opencl.so /usr/lib/i386-linux-gnu/libdlfaker.so /usr/lib/i386-linux-gnu/libgefaker.so; \
    elif [ "$(dpkg --print-architecture)" = "arm64" ]; then \
    curl -fsSL ${CURL_RETRY_OPTS} -O "https://github.com/VirtualGL/virtualgl/releases/download/${VIRTUALGL_VERSION}/virtualgl_${VIRTUALGL_VERSION}_arm64.deb" && \
    apt-get update && apt-get install -y --no-install-recommends ./virtualgl_${VIRTUALGL_VERSION}_arm64.deb && \
    rm -f "virtualgl_${VIRTUALGL_VERSION}_arm64.deb" && \
    chmod -f u+s /usr/lib/libvglfaker.so /usr/lib/libvglfaker-nodl.so /usr/lib/libdlfaker.so /usr/lib/libgefaker.so; fi && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*

# Anything below this line should always be kept the same between docker-selkies-glx-desktop and docker-selkies-egl-desktop

# Install KDE and other GUI packages
RUN mkdir -pm755 /etc/apt/preferences.d && echo "Package: firefox*\n\
Pin: version 1:1snap*\n\
Pin-Priority: -1" > /etc/apt/preferences.d/firefox-nosnap && \
    mkdir -pm755 /etc/apt/trusted.gpg.d && curl -fsSL ${CURL_RETRY_OPTS} "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x738BEB9321D1AAEC13EA9391AEBDF4819BE21867" | gpg --dearmor -o /etc/apt/trusted.gpg.d/mozillateam-ubuntu-ppa.gpg && \
    mkdir -pm755 /etc/apt/sources.list.d && echo "deb https://ppa.launchpadcontent.net/mozillateam/ppa/ubuntu $(grep '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 | tr -d '\"') main" > "/etc/apt/sources.list.d/mozillateam-ubuntu-ppa-$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 | tr -d '\"').list" && \
    apt-get update && apt-get install --no-install-recommends -y \
        plasma-desktop \
        plasma-workspace \
        kwin-x11 \
        dbus-x11 \
        dolphin \
        kio \
        konsole \
        plasma-discover \
        breeze \
        breeze-cursor-theme \
        breeze-gtk-theme \
        breeze-icon-theme \
        appmenu-gtk3-module \
        qt5-gtk-platformtheme \
        desktop-file-utils \
        libdbusmenu-glib4 \
        libdbusmenu-gtk3-4 \
        firefox \
        xdg-user-dirs \
        xdg-utils && \
    # Ensure Firefox as the default web browser
    xdg-settings set default-web-browser firefox.desktop && \
    update-alternatives --set x-www-browser /usr/bin/firefox && \
    rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/* || true && \
    rm -rf /usr/share/wallpapers /usr/share/backgrounds || true && \
    rm -rf /usr/share/sounds || true && \
    rm -rf \
        /usr/share/icons/Adwaita \
        /usr/share/icons/Breeze_Snow \
        /usr/share/icons/Humanity \
        /usr/share/icons/Humanity-Dark \
        /usr/share/icons/LoginIcons \
        /usr/share/icons/ubuntu-mono-dark \
        /usr/share/icons/ubuntu-mono-light || true && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/* && \
    # Fix KDE startup permissions issues in containers
    MULTI_ARCH=$(dpkg --print-architecture | sed -e 's/arm64/aarch64-linux-gnu/' -e 's/armhf/arm-linux-gnueabihf/' -e 's/riscv64/riscv64-linux-gnu/' -e 's/ppc64el/powerpc64le-linux-gnu/' -e 's/s390x/s390x-linux-gnu/' -e 's/i.*86/i386-linux-gnu/' -e 's/amd64/x86_64-linux-gnu/' -e 's/unknown/x86_64-linux-gnu/') && \
    cp -f /usr/lib/${MULTI_ARCH}/libexec/kf5/start_kdeinit /tmp/ && \
    rm -f /usr/lib/${MULTI_ARCH}/libexec/kf5/start_kdeinit && \
    cp -f /tmp/start_kdeinit /usr/lib/${MULTI_ARCH}/libexec/kf5/start_kdeinit && \
    rm -f /tmp/start_kdeinit && \
    # KDE disable screen lock, double-click to open instead of single-click
    echo "[Daemon]\n\
Autolock=false\n\
LockOnResume=false" > /etc/xdg/kscreenlockerrc && \
    echo "[Compositing]\n\
Enabled=false" > /etc/xdg/kwinrc && \
    echo "[KDE]\n\
SingleClick=false\n\
\n\
[KDE Action Restrictions]\n\
action/lock_screen=false\n\
logout=false\n\
\n\
[General]\n\
BrowserApplication=firefox.desktop" > /etc/xdg/kdeglobals
# KDE environment variables
ENV DESKTOP_SESSION=plasma
ENV XDG_SESSION_DESKTOP=KDE
ENV XDG_CURRENT_DESKTOP=KDE
ENV XDG_SESSION_TYPE=x11
ENV KDE_FULL_SESSION=true
ENV KDE_SESSION_VERSION=5
ENV KDE_APPLICATIONS_AS_SCOPE=1
ENV KWIN_COMPOSE=N
ENV KWIN_EFFECTS_FORCE_ANIMATIONS=0
ENV KWIN_EXPLICIT_SYNC=0
ENV KWIN_X11_NO_SYNC_TO_VBLANK=1
# Use sudoedit to change protected files instead of using sudo on kwrite
ENV SUDO_EDITOR=vim
# Enable AppImage execution in containers
ENV APPIMAGE_EXTRACT_AND_RUN=1

# Lutris and Heroic Launcher (without Wine)
RUN if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
     add-apt-repository -y universe && \
     add-apt-repository -y multiverse && \
     apt-get update && \
     LUTRIS_VERSION="$(curl -fsSL ${CURL_RETRY_OPTS} "https://api.github.com/repos/lutris/lutris/releases/latest" | jq -r '.tag_name' | sed 's/[^0-9\.\-]*//g')" && \
     cd /tmp && curl -o lutris.deb -fsSL ${CURL_RETRY_OPTS} "https://github.com/lutris/lutris/releases/download/v${LUTRIS_VERSION}/lutris_${LUTRIS_VERSION}_all.deb" && apt-get install --no-install-recommends -y ./lutris.deb && rm -f lutris.deb && \
     HEROIC_VERSION="$(curl -fsSL ${CURL_RETRY_OPTS} "https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest" | jq -r '.tag_name' | sed 's/[^0-9\.\-]*//g')" && \
     cd /tmp && curl -o heroic_launcher.deb -fsSL ${CURL_RETRY_OPTS} "https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/releases/download/v${HEROIC_VERSION}/Heroic-${HEROIC_VERSION}-linux-$(dpkg --print-architecture).deb" && apt-get install --no-install-recommends -y ./heroic_launcher.deb && rm -f heroic_launcher.deb && \
     apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*; fi

# Steam (install as root during build; runs as non-root user at runtime)
RUN if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
    dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        python3-protobuf \
        xdg-desktop-portal \
        xdg-desktop-portal-kde \
        curl \
        udev \
        pciutils \
        libcanberra-gtk-module \
        libgl1 \
        libgl1:i386 \
        libudev1:i386 \
        libcap2:i386 && \
    # Recommended for controller rules (udev) and desktop integration
    (apt-get install -y --no-install-recommends steam-devices) || true && \
    cd /tmp && curl -fsSL ${CURL_RETRY_OPTS} -o steam_latest.deb "https://repo.steampowered.com/steam/archive/stable/steam_latest.deb" && \
    apt-get install -y ./steam_latest.deb && \
    # Ensure the launcher package is present (some distros treat the .deb as a repo bootstrapper)
    (apt-get install -y --no-install-recommends steam-launcher) || true && \
    # Hard check: fail the build if steam isn't available after install
    command -v steam >/dev/null 2>&1 && \
    rm -f /tmp/steam_latest.deb && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*; \
fi

# pkexec permissions (safe if pkexec is absent)
RUN if [ -x /usr/bin/pkexec ]; then \
        ls -l /usr/bin/pkexec && \
        chmod u+s /usr/bin/pkexec || true; \
    else \
        echo "pkexec not present"; \
    fi

# Install latest Selkies (https://github.com/selkies-project/selkies) build, Python application, and web application, should be consistent with Selkies documentation
ARG PIP_BREAK_SYSTEM_PACKAGES=1
RUN apt-get update && apt-get install --no-install-recommends -y \
        # GStreamer dependencies
        python3-pip \
        python3-dev \
        python3-gi \
        python3-setuptools \
        python3-wheel \
        libgcrypt20 \
        libgirepository-1.0-1 \
        glib-networking \
        libglib2.0-0 \
        libgudev-1.0-0 \
        alsa-utils \
        jackd2 \
        libjack-jackd2-0 \
        libpulse0 \
        libopus0 \
        libvpx-dev \
        x264 \
        x265 \
        libdrm2 \
        libegl1 \
        libgl1 \
        libopengl0 \
        libgles1 \
        libgles2 \
        libglvnd0 \
        libglx0 \
        libwayland-egl1 \
        wmctrl \
        xsel \
        xdotool \
        x11-utils \
        x11-xkb-utils \
        x11-xserver-utils \
        xserver-xorg-core \
        libx11-xcb1 \
        libxcb-dri3-0 \
        libxdamage1 \
        libxfixes3 \
        libxv1 \
        libxtst6 \
        libxext6 && \
        if [ "$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '\"')" \> "20.04" ]; then apt-get install --no-install-recommends -y xcvt libopenh264-dev svt-av1 aom-tools; else apt-get install --no-install-recommends -y mesa-utils-extra; fi  # Install Selkies components from CDN (cdn.warplay.cloud)

#
# Selkies artifact source selection:
# - cdn (default): download the latest release from WARPLAY-CLOUD CDN at build time
# - local: use pre-downloaded artifacts from install_to_docker/ (offline / air-gapped builds)
ARG SELKIES_SOURCE=cdn

ARG CACHE_BREAKER=default

RUN --mount=type=bind,source=install_to_docker,target=/tmp/install_to_docker,ro \
    set -e; \
    SELKIES_SOURCE="${SELKIES_SOURCE}"; \
    UBUNTU_VERSION="$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')"; \
    ARCH="$(dpkg --print-architecture)"; \
    FALLBACK_RELEASES="${UBUNTU_VERSION} 22.04 20.04"; \
    STATE_DIR="/opt/selkies-install"; \
    mkdir -p "${STATE_DIR}/cache"; \
    detect_local_dir() { \
      local base="/tmp/install_to_docker"; \
      local candidate="${base}/selkies"; \
      if [ -d "${candidate}" ]; then \
        for rel in ${FALLBACK_RELEASES}; do \
          if ls -1 "${candidate}/gstreamer-selkies_gpl_v"*"_ubuntu${rel}_${ARCH}.tar.gz" >/dev/null 2>&1; then \
            echo "${candidate}"; \
            return 0; \
          fi; \
        done; \
      fi; \
      echo "${base}"; \
    }; \
	    detect_local_version() { \
	      local local_dir="$1"; \
	      local f v; \
	      f="$(ls -1 "${local_dir}/selkies_gstreamer-"*.whl 2>/dev/null | head -n 1 || true)"; \
      if [ -n "${f}" ]; then \
        v="$(basename "${f}")"; \
        v="${v#selkies_gstreamer-}"; \
        v="${v%-py3-none-any.whl}"; \
        if [ -n "${v}" ]; then echo "${v}"; return 0; fi; \
      fi; \
      f="$(ls -1 "${local_dir}/selkies-gstreamer-web_v"*.tar.gz 2>/dev/null | head -n 1 || true)"; \
	      if [ -n "${f}" ]; then \
	        v="$(basename "${f}")"; \
	        v="${v#selkies-gstreamer-web_v}"; \
	        v="${v%.tar.gz}"; \
	        if [ -n "${v}" ]; then echo "${v}"; return 0; fi; \
	      fi; \
	      f="$(ls -1 "${local_dir}/gstreamer-selkies_gpl_v"*"_ubuntu"*".tar.gz" 2>/dev/null | head -n 1 || true)"; \
	      if [ -n "${f}" ]; then \
	        v="$(basename "${f}")"; \
	        v="${v#gstreamer-selkies_gpl_v}"; \
        v="${v%%_ubuntu*}"; \
        if [ -n "${v}" ]; then echo "${v}"; return 0; fi; \
      fi; \
      return 1; \
    }; \
    apply_copy_overlay_if_present() { \
      local local_dir="$1"; \
      local copy_dir="${local_dir}/copy_to_docker"; \
      if [ ! -d "${copy_dir}" ]; then \
        copy_dir="/tmp/install_to_docker/copy_to_docker"; \
      fi; \
      if [ -d "${copy_dir}" ] && [ -n "$(ls -A "${copy_dir}" 2>/dev/null || true)" ]; then \
        echo "Applying ${copy_dir} overlay to /"; \
        cp -a "${copy_dir}/." /; \
      fi; \
    }; \
    if [ "${SELKIES_SOURCE}" = "cdn" ]; then \
      echo "Fetching latest Selkies version from CDN..."; \
      SELKIES_VERSION="$(curl -fsSL ${CURL_RETRY_OPTS} "https://cdn.warplay.cloud/drivers/linux/system/selkies/releases/latest" | jq -r '.tag_name')"; \
      if [ -z "${SELKIES_VERSION}" ] || [ "${SELKIES_VERSION}" = "null" ]; then \
        echo "ERROR: Failed to fetch Selkies version from CDN" >&2; \
        exit 1; \
      fi; \
    elif [ "${SELKIES_SOURCE}" = "local" ]; then \
      LOCAL_DIR="$(detect_local_dir)"; \
      SELKIES_VERSION="$(detect_local_version "${LOCAL_DIR}" || true)"; \
	      if [ -z "${SELKIES_VERSION}" ]; then \
	        echo "ERROR: SELKIES_SOURCE=local but can't detect Selkies version from artifacts in ${LOCAL_DIR}" >&2; \
	        echo "  Provide at least one of:" >&2; \
	        echo "    - selkies_gstreamer-<version>-py3-none-any.whl" >&2; \
	        echo "    - selkies-gstreamer-web_v<version>.tar.gz" >&2; \
	        echo "    - gstreamer-selkies_gpl_v<version>_ubuntu<release>_<arch>.tar.gz" >&2; \
	        exit 1; \
	      fi; \
      apply_copy_overlay_if_present "${LOCAL_DIR}"; \
    else \
      echo "ERROR: SELKIES_SOURCE must be 'cdn' or 'local' (got '${SELKIES_SOURCE}')" >&2; \
      exit 1; \
    fi; \
    CDN_BASE_URL="https://cdn.warplay.cloud/drivers/linux/system/selkies/releases/download/v${SELKIES_VERSION}"; \
    echo "Selkies source: ${SELKIES_SOURCE}"; \
    echo "Ubuntu Version: ${UBUNTU_VERSION}"; \
    echo "Architecture: ${ARCH}"; \
    echo "CDN Base URL: ${CDN_BASE_URL}"; \
    echo "Selkies Version: ${SELKIES_VERSION}"; \
    # Step 1: GStreamer bundle \
    GSTREAMER_FALLBACK_TO_CDN=false; \
    if [ "${SELKIES_SOURCE}" = "local" ]; then \
      LOCAL_DIR="${LOCAL_DIR:-$(detect_local_dir)}"; \
      GSTREAMER_FILE=""; \
      for rel in ${FALLBACK_RELEASES}; do \
        f="$(ls -1 "${LOCAL_DIR}/gstreamer-selkies_gpl_v"*"_ubuntu${rel}_${ARCH}.tar.gz" 2>/dev/null | head -n 1 || true)"; \
        if [ -n "${f}" ]; then \
	          echo "[1/3] Using local GStreamer bundle for Ubuntu ${rel}: $(basename "${f}")"; \
          GSTREAMER_FILE="${f}"; \
          break; \
        fi; \
      done; \
      if [ -n "${GSTREAMER_FILE}" ]; then \
        gzip -t "${GSTREAMER_FILE}" >/dev/null 2>&1 || { echo "ERROR: corrupted gzip: ${GSTREAMER_FILE}" >&2; exit 1; }; \
        tar -xzf "${GSTREAMER_FILE}" -C /opt; \
      else \
	        echo "[1/3] No local GStreamer bundle found, falling back to CDN"; \
        GSTREAMER_FALLBACK_TO_CDN=true; \
      fi; \
    fi; \
    if [ "${SELKIES_SOURCE}" = "cdn" ] || [ "${GSTREAMER_FALLBACK_TO_CDN}" = "true" ]; then \
	      echo "[1/3] Downloading GStreamer Selkies GPL bundle..."; \
      chosen=""; \
      for rel in ${FALLBACK_RELEASES}; do \
        name="gstreamer-selkies_gpl_v${SELKIES_VERSION}_ubuntu${rel}_${ARCH}.tar.gz"; \
        cached="${STATE_DIR}/cache/${name}"; \
        echo "  - Trying: ${name}"; \
        if [ -f "${cached}" ] && gzip -t "${cached}" >/dev/null 2>&1; then \
          chosen="${cached}"; \
          echo "  - Using cached bundle (Ubuntu ${rel})"; \
          break; \
        fi; \
        if curl ${CURL_RETRY_OPTS} -fSL --progress-bar -o "${cached}" "${CDN_BASE_URL}/${name}"; then \
          if gzip -t "${cached}" >/dev/null 2>&1; then \
            chosen="${cached}"; \
            echo "  - Downloaded and cached (Ubuntu ${rel})"; \
            break; \
          fi; \
          rm -f "${cached}" || true; \
        fi; \
      done; \
      if [ -z "${chosen}" ] || [ ! -f "${chosen}" ]; then \
        echo "ERROR: failed to download any compatible GStreamer bundle from CDN" >&2; \
        exit 1; \
      fi; \
      tar -xzf "${chosen}" -C /opt; \
    fi; \
    # Step 2: Python wheel \
    if [ "${SELKIES_SOURCE}" = "local" ]; then \
      LOCAL_DIR="${LOCAL_DIR:-$(detect_local_dir)}"; \
      WHL="$(ls -1 "${LOCAL_DIR}/selkies_gstreamer-"*.whl 2>/dev/null | sort -V | tail -n 1 || true)"; \
      if [ -z "${WHL}" ]; then \
        echo "ERROR: Missing local Python wheel in ${LOCAL_DIR}" >&2; \
        exit 1; \
      fi; \
	      echo "[2/3] Installing local Python wheel: $(basename "${WHL}")"; \
      pip3 install --no-cache-dir --force-reinstall --ignore-installed idna "${WHL}" "websockets<14.0"; \
    else \
	      echo "[2/3] Downloading and installing Python wheel..."; \
      cd /tmp; \
      WHL="selkies_gstreamer-${SELKIES_VERSION}-py3-none-any.whl"; \
      curl ${CURL_RETRY_OPTS} -fSL --progress-bar -o "${WHL}" "${CDN_BASE_URL}/${WHL}"; \
      pip3 install --no-cache-dir --force-reinstall --ignore-installed idna "${WHL}" "websockets<14.0"; \
      rm -f "${WHL}" || true; \
    fi; \
	  rm -rf /opt/gst-web /opt/gst-web-react || true; \
	    rm -rf "${STATE_DIR}" || true; \
	    apt-get clean; \
	    rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /var/tmp/*; \
	    rm -rf /tmp/* || true

# Copy scripts and configurations used to start the container with `--chown=1000:1000`
COPY --chown=1000:1000 --chmod=0755 \
    entrypoint.sh \
    selkies-gstreamer-entrypoint.sh \
    warplay-control-entrypoint.sh \
    supervisord.conf \
    /etc/

SHELL ["/bin/sh", "-c"]

USER 0
# Enable sudo through sudo-root with uid 0
RUN if [ -d "/usr/libexec/sudo" ]; then SUDO_LIB="/usr/libexec/sudo"; else SUDO_LIB="/usr/lib/sudo"; fi && \
    chown -R -f -h --no-preserve-root root:root /usr/bin/sudo-root /etc/sudo.conf /etc/sudoers /etc/sudoers.d /etc/sudo_logsrvd.conf "${SUDO_LIB}" || echo 'Failed to provide root permissions in some paths relevant to sudo' && \
    chmod -f 4755 /usr/bin/sudo-root || echo 'Failed to set chmod setuid for root' && \
    (id -u steam >/dev/null 2>&1 || useradd -m -s /bin/bash steam) && \
    usermod -a -G audio,video,render,input,plugdev steam || echo 'Failed to update steam user groups'
USER 1000

ENV PIPEWIRE_LATENCY="128/48000"
ENV XDG_RUNTIME_DIR=/tmp/runtime-ubuntu
ENV PIPEWIRE_RUNTIME_DIR="${PIPEWIRE_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/tmp}}"
ENV PULSE_RUNTIME_PATH="${PULSE_RUNTIME_PATH:-${XDG_RUNTIME_DIR:-/tmp}/pulse}"
ENV PULSE_SERVER="${PULSE_SERVER:-unix:${PULSE_RUNTIME_PATH:-${XDG_RUNTIME_DIR:-/tmp}/pulse}/native}"

# dbus-daemon to the below address is required during startup
ENV DBUS_SYSTEM_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR:-/tmp}/dbus-system-bus"

USER 1000
ENV SHELL=/bin/bash
ENV USER=ubuntu
ENV HOME=/home/ubuntu
WORKDIR /home/ubuntu

EXPOSE 8080

ENTRYPOINT ["/usr/bin/supervisord"]
