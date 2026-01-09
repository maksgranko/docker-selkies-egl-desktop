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
        cups-browsed \
        cups-bsd \
        cups-common \
        cups-filters \
        printer-driver-cups-pdf \
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
        python3-cups \
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
        fonts-noto-color-emoji \
        fonts-noto-extra \
        fonts-noto-ui-extra \
        fonts-noto-hinted \
        fonts-noto-mono \
        fonts-noto-unhinted \
        fonts-opensymbol \
        fonts-symbola \
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
        xserver-xorg-input-wacom \
        xserver-xorg-video-all \
        xserver-xorg-video-intel \
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
        # NGINX web server
        nginx \
        apache2-utils \
        netcat-openbsd && \
    # Sanitize NGINX path
    sed -i -e 's/\/var\/log\/nginx\/access\.log/\/dev\/stdout/g' -e 's/\/var\/log\/nginx\/error\.log/\/dev\/stderr/g' -e 's/\/run\/nginx\.pid/\/tmp\/nginx\.pid/g' /etc/nginx/nginx.conf && \
    echo "error_log /dev/stderr;" >> /etc/nginx/nginx.conf && \
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
        intel-gpu-tools \
        nvtop \
        va-driver-all \
        i965-va-driver-shaders \
        intel-media-va-driver-non-free \
        va-driver-all:i386 \
        i965-va-driver-shaders:i386 \
        intel-media-va-driver-non-free:i386 \
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
ENV KASMVNC_ENABLE=false
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
        kde-baseapps \
        plasma-desktop \
        plasma-workspace \
        adwaita-icon-theme-full \
        appmenu-gtk3-module \
        ark \
        aspell \
        aspell-en \
        breeze \
        breeze-cursor-theme \
        breeze-gtk-theme \
        breeze-icon-theme \
        dbus-x11 \
        debconf-kde-helper \
        desktop-file-utils \
        dolphin \
        dolphin-plugins \
        enchant-2 \
        fcitx \
        fcitx-frontend-gtk2 \
        fcitx-frontend-gtk3 \
        fcitx-frontend-qt5 \
        fcitx-module-dbus \
        fcitx-module-kimpanel \
        fcitx-module-lua \
        fcitx-module-x11 \
        fcitx-tools \
        fcitx-hangul \
        fcitx-libpinyin \
        fcitx-m17n \
        fcitx-mozc \
        fcitx-sayura \
        fcitx-unikey \
        filelight \
        frameworkintegration \
        gwenview \
        haveged \
        hunspell \
        im-config \
        kwrite \
        kcalc \
        kcharselect \
        kdeadmin \
        kde-config-fcitx \
        kde-config-gtk-style \
        kde-config-gtk-style-preview \
        kdeconnect \
        kdegraphics-thumbnailers \
        kde-spectacle \
        kdf \
        kdialog \
        kfind \
        kget \
        khotkeys \
        kimageformat-plugins \
        kinfocenter \
        kio \
        kio-extras \
        kmag \
        kmenuedit \
        kmix \
        kmousetool \
        kmouth \
        ksshaskpass \
        ktimer \
        kwin-addons \
        kwin-x11 \
        libdbusmenu-glib4 \
        libdbusmenu-gtk3-4 \
        libgail-common \
        libgdk-pixbuf2.0-bin \
        libgtk2.0-bin \
        libgtk-3-bin \
        libkf5baloowidgets-bin \
        libkf5dbusaddons-bin \
        libkf5iconthemes-bin \
        libkf5kdelibs4support5-bin \
        libkf5khtml-bin \
        libkf5parts-plugins \
        libqt5multimedia5-plugins \
        librsvg2-common \
        media-player-info \
        okular \
        okular-extra-backends \
        plasma-browser-integration \
        plasma-calendar-addons \
        plasma-dataengines-addons \
        plasma-discover \
        plasma-integration \
        plasma-runners-addons \
        plasma-widgets-addons \
        print-manager \
        qapt-deb-installer \
        qml-module-org-kde-runnermodel \
        qml-module-org-kde-qqc2desktopstyle \
        qml-module-qtgraphicaleffects \
        qml-module-qt-labs-platform \
        qml-module-qtquick-xmllistmodel \
        qt5-gtk-platformtheme \
        qt5-image-formats-plugins \
        qt5-style-plugins \
        qtspeech5-flite-plugin \
        qtvirtualkeyboard-plugin \
        software-properties-qt \
        sonnet-plugins \
        sweeper \
        systemsettings \
        ubuntu-drivers-common \
        vlc \
        vlc-plugin-access-extra \
        vlc-plugin-notify \
        vlc-plugin-samba \
        vlc-plugin-skins2 \
        vlc-plugin-video-splitter \
        vlc-plugin-visualization \
        xdg-user-dirs \
        xdg-utils \
        firefox \
        transmission-qt && \
    # apt-get install --install-recommends -y \
    #     libreoffice \
    #     libreoffice-kf5 \
    #     libreoffice-plasma \
    #     libreoffice-style-breeze && \
    # Ensure Firefox as the default web browser
    xdg-settings set default-web-browser firefox.desktop && \
    update-alternatives --set x-www-browser /usr/bin/firefox && \
    # Install Google Chrome for supported architectures
    if [ "$(dpkg --print-architecture)" = "amd64" ]; then cd /tmp && curl ${CURL_RETRY_OPTS} -o google-chrome-stable.deb -fsSL "https://dl.google.com/linux/direct/google-chrome-stable_current_$(dpkg --print-architecture).deb" && apt-get update && apt-get install --no-install-recommends -y ./google-chrome-stable.deb && rm -f google-chrome-stable.deb && sed -i '/^Exec=/ s/$/ --password-store=basic --in-process-gpu/' /usr/share/applications/google-chrome.desktop; fi && \
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
ENV SUDO_EDITOR=kwrite
# Enable AppImage execution in containers
ENV APPIMAGE_EXTRACT_AND_RUN=1
# Set input to fcitx
ENV GTK_IM_MODULE=fcitx
ENV QT_IM_MODULE=fcitx
ENV XIM=fcitx
ENV XMODIFIERS="@im=fcitx"

# Wine, Winetricks, and launchers, this process must be consistent with https://wiki.winehq.org/Ubuntu
ARG WINE_BRANCH=staging
RUN if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
    mkdir -pm755 /etc/apt/keyrings && curl -fsSL ${CURL_RETRY_OPTS} -o /etc/apt/keyrings/winehq-archive.key "https://dl.winehq.org/wine-builds/winehq.key" && \
    curl -fsSL ${CURL_RETRY_OPTS} -o "/etc/apt/sources.list.d/winehq-$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 | tr -d '\"').sources" "https://dl.winehq.org/wine-builds/ubuntu/dists/$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 | tr -d '\"')/winehq-$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 | tr -d '\"').sources" && \
    apt-get update && apt-get install --install-recommends -y \
        winehq-${WINE_BRANCH} && \
    apt-get install --no-install-recommends -y \
        q4wine \
        playonlinux && \
    LUTRIS_VERSION="$(curl -fsSL ${CURL_RETRY_OPTS} "https://api.github.com/repos/lutris/lutris/releases/latest" | jq -r '.tag_name' | sed 's/[^0-9\.\-]*//g')" && \
    cd /tmp && curl -o lutris.deb -fsSL ${CURL_RETRY_OPTS} "https://github.com/lutris/lutris/releases/download/v${LUTRIS_VERSION}/lutris_${LUTRIS_VERSION}_all.deb" && apt-get install --no-install-recommends -y ./lutris.deb && rm -f lutris.deb && \
    HEROIC_VERSION="$(curl -fsSL ${CURL_RETRY_OPTS} "https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest" | jq -r '.tag_name' | sed 's/[^0-9\.\-]*//g')" && \
    cd /tmp && curl -o heroic_launcher.deb -fsSL ${CURL_RETRY_OPTS} "https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/releases/download/v${HEROIC_VERSION}/Heroic-${HEROIC_VERSION}-linux-$(dpkg --print-architecture).deb" && apt-get install --no-install-recommends -y ./heroic_launcher.deb && rm -f heroic_launcher.deb && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/* && \
    curl -o /usr/bin/winetricks -fsSL ${CURL_RETRY_OPTS} "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks" && \
    chmod -f 755 /usr/bin/winetricks && \
    curl -o /usr/share/bash-completion/completions/winetricks -fsSL ${CURL_RETRY_OPTS} "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks.bash-completion"; fi


# Steam (install as root during build; runs as non-root user at runtime)
# Optional: install pkexec via policykit-1 by setting --build-arg INSTALL_POLKIT=true
ARG INSTALL_POLKIT=false
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
    (apt-get update && apt-get install -y --no-install-recommends steam-devices) || true && \
    if [ "$(echo ${INSTALL_POLKIT} | tr '[:upper:]' '[:lower:]')" = "true" ]; then \
        apt-get update && apt-get install -y --no-install-recommends policykit-1; \
    fi && \
    cd /tmp && curl -fsSL ${CURL_RETRY_OPTS} -o steam_latest.deb "https://repo.steampowered.com/steam/archive/stable/steam_latest.deb" && \
    apt-get update && apt-get install -y ./steam_latest.deb && \
    # Ensure the launcher package is present (some distros treat the .deb as a repo bootstrapper)
    (apt-get update && apt-get install -y --no-install-recommends steam-launcher) || true && \
    # Hard check: fail the build if steam isn't available after install
    command -v steam >/dev/null 2>&1 && \
    rm -f /tmp/steam_latest.deb && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*; \
fi

# pkexec permissions (run outside INSTALL_POLKIT block; safe if pkexec is absent)
RUN if [ -x /usr/bin/pkexec ]; then \
        ls -l /usr/bin/pkexec && \
        chmod u+s /usr/bin/pkexec || true; \
    else \
        echo "pkexec not present (policykit-1 not installed)"; \
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
        wayland-protocols \
        libwayland-dev \
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

ARG SELKIES_LOCAL_DIR=
COPY install_to_docker/selkies/ /tmp/selkies/
ARG CACHE_BREAKER=default

RUN     echo "======================================== " && \
        LOCAL_GSTREAMER_FILE="" && \
        for f in /tmp/selkies/gstreamer-selkies_gpl_v*.tar.gz; do if [ -f "$f" ]; then LOCAL_GSTREAMER_FILE="$f"; break; fi; done && \
        LOCAL_WHL_FILE="" && \
        for f in /tmp/selkies/selkies_gstreamer-*.whl; do if [ -f "$f" ]; then LOCAL_WHL_FILE="$f"; break; fi; done && \
        LOCAL_WEB_FILE="" && \
        for f in /tmp/selkies/selkies-gstreamer-web_v*.tar.gz; do if [ -f "$f" ]; then LOCAL_WEB_FILE="$f"; break; fi; done && \
        LOCAL_JS_DEB_FILE="" && \
        for f in /tmp/selkies/selkies-js-interposer_v*.deb; do if [ -f "$f" ]; then LOCAL_JS_DEB_FILE="$f"; break; fi; done && \
        if [ -z "${SELKIES_LOCAL_DIR}" ]; then \
            echo "SELKIES_LOCAL_DIR not set. Using CDN." && \
            USE_LOCAL=false; \
        else \
            MISSING_LOCAL="" && \
            if [ -z "${LOCAL_WHL_FILE}" ]; then MISSING_LOCAL="${MISSING_LOCAL} selkies_gstreamer-whl"; fi && \
            if [ -z "${LOCAL_WEB_FILE}" ]; then MISSING_LOCAL="${MISSING_LOCAL} selkies-gstreamer-web"; fi && \
            if [ -z "${LOCAL_JS_DEB_FILE}" ]; then MISSING_LOCAL="${MISSING_LOCAL} selkies-js-interposer"; fi && \
            if [ -n "${MISSING_LOCAL}" ]; then \
                echo "Local Selkies artifacts not found:${MISSING_LOCAL}. Falling back to CDN." && \
                USE_LOCAL=false; \
            else \
                echo "Using local Selkies artifacts from /tmp/selkies" && \
                USE_LOCAL=true; \
            fi; \
        fi && \
        if [ "${USE_LOCAL}" = "true" ]; then \
            SELKIES_VERSION="" && \
            if [ -n "${LOCAL_WHL_FILE}" ]; then \
                SELKIES_VERSION="$(basename "${LOCAL_WHL_FILE}")"; \
                SELKIES_VERSION="${SELKIES_VERSION#selkies_gstreamer-}"; \
                SELKIES_VERSION="${SELKIES_VERSION%-py3-none-any.whl}"; \
            elif [ -n "${LOCAL_WEB_FILE}" ]; then \
                SELKIES_VERSION="$(basename "${LOCAL_WEB_FILE}" | sed -e 's/^selkies-gstreamer-web_v//' -e 's/\\.tar\\.gz$//')"; \
            elif [ -n "${LOCAL_JS_DEB_FILE}" ]; then \
                SELKIES_VERSION="$(basename "${LOCAL_JS_DEB_FILE}" | sed -e 's/^selkies-js-interposer_v//' -e 's/_ubuntu.*\\.deb$//')"; \
            fi && \
            if [ -z "${SELKIES_VERSION}" ]; then \
                echo "Local Selkies version not detected. Using CDN latest for GStreamer only."; \
            fi; \
        fi && \
        if [ "${USE_LOCAL}" = "true" ]; then \
            if [ -n "${LOCAL_GSTREAMER_FILE}" ]; then \
                echo "[1/4] Installing local GStreamer Selkies GPL bundle..." && \
                cd /opt && tar -xzf "${LOCAL_GSTREAMER_FILE}"; \
            else \
                echo "[1/4] Local GStreamer bundle not found. Downloading from CDN..." && \
                if [ -z "${SELKIES_VERSION}" ]; then \
                    SELKIES_VERSION="$(curl -fsSL ${CURL_RETRY_OPTS} 'https://cdn.warplay.cloud/drivers/linux/system/selkies/releases/latest' | jq -r '.tag_name')"; \
                fi && \
                UBUNTU_VERSION="$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '\"')" && \
                ARCH="$(dpkg --print-architecture)" && \
                CDN_BASE_URL="https://cdn.warplay.cloud/drivers/linux/system/selkies/releases/download/v${SELKIES_VERSION}" && \
                GSTREAMER_FILE="gstreamer-selkies_gpl_v${SELKIES_VERSION}_ubuntu${UBUNTU_VERSION}_${ARCH}.tar.gz" && \
                echo "  - File: ${GSTREAMER_FILE}" && \
                echo "  - URL: ${CDN_BASE_URL}/${GSTREAMER_FILE}" && \
                cd /tmp && \
                curl ${CURL_RETRY_OPTS} -fSL --progress-bar -w "HTTP Status: %{http_code}, Size: %{size_download} bytes\n" \
                    -o "${GSTREAMER_FILE}" "${CDN_BASE_URL}/${GSTREAMER_FILE}" && \
                cd /opt && tar -xzf "/tmp/${GSTREAMER_FILE}" && \
                rm -f "/tmp/${GSTREAMER_FILE}"; \
            fi && \
            echo "[2/4] Installing local Selkies GStreamer Python package..." && \
            pip3 install --no-cache-dir --force-reinstall --ignore-installed idna "${LOCAL_WHL_FILE}" "websockets<14.0" && \
            echo "[3/4] Installing local Selkies GStreamer Web interface..." && \
            cd /opt && tar -xzf "${LOCAL_WEB_FILE}" && \
            if [ -d "/opt/gst-web-react" ] && [ ! -d "/opt/gst-web" ]; then \
                mv /opt/gst-web-react /opt/gst-web; \
            fi && \
            echo "[4/4] Installing local Selkies JS Interposer..." && \
            apt-get update && apt-get install --no-install-recommends -y "${LOCAL_JS_DEB_FILE}" && \
            echo "Local Selkies installation completed successfully!"; \
        else \
            SELKIES_VERSION="$(curl -fsSL ${CURL_RETRY_OPTS} 'https://cdn.warplay.cloud/drivers/linux/system/selkies/releases/latest' | jq -r '.tag_name')" && \
            if [ -z "${SELKIES_VERSION}" ] || [ "${SELKIES_VERSION}" = "null" ]; then \
                echo "? ERROR: Failed to fetch Selkies version from CDN" && \
                echo "  Please check: https://cdn.warplay.cloud/drivers/linux/system/selkies/releases/latest" && \
                exit 1; \
            fi && \
            echo "? Latest Selkies version: ${SELKIES_VERSION}" && \
            UBUNTU_VERSION="$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')" && \
            ARCH="$(dpkg --print-architecture)" && \
            CDN_BASE_URL="https://cdn.warplay.cloud/drivers/linux/system/selkies/releases/download/v${SELKIES_VERSION}" && \
            echo "Ubuntu Version: ${UBUNTU_VERSION}" && \
            echo "Architecture: ${ARCH}" && \
            echo "CDN Base URL: ${CDN_BASE_URL}" && \
            echo "========================================" && \
            # Step 1: Download and extract GStreamer Selkies GPL bundle to /opt
            echo "[1/4] Downloading GStreamer Selkies GPL bundle..." && \
            GSTREAMER_FILE="gstreamer-selkies_gpl_v${SELKIES_VERSION}_ubuntu${UBUNTU_VERSION}_${ARCH}.tar.gz" && \
            echo "  - File: ${GSTREAMER_FILE}" && \
            echo "  - URL: ${CDN_BASE_URL}/${GSTREAMER_FILE}" && \
            cd /tmp && \
            echo "  - Downloading file (this may take a while)..." && \
            curl ${CURL_RETRY_OPTS} -fSL --progress-bar -w "HTTP Status: %{http_code}, Size: %{size_download} bytes\n" \
                -o "${GSTREAMER_FILE}" "${CDN_BASE_URL}/${GSTREAMER_FILE}" && \
            if [ ! -f "${GSTREAMER_FILE}" ]; then \
                echo "  ? ERROR: File was not downloaded!" && exit 1; \
            fi && \
            FILE_SIZE=$(stat -c%s "${GSTREAMER_FILE}" 2>/dev/null || stat -f%z "${GSTREAMER_FILE}" 2>/dev/null) && \
            FILE_SIZE_MB=$((FILE_SIZE / 1024 / 1024)) && \
            echo "  - Downloaded file size: ${FILE_SIZE_MB} MB (${FILE_SIZE} bytes)" && \
            if [ ${FILE_SIZE} -lt 10000000 ]; then \
                echo "  ? ERROR: File is too small (< 10 MB), probably download failed or CDN error" && \
                echo "  - File contents preview:" && \
                head -20 "${GSTREAMER_FILE}" && \
                exit 1; \
            fi && \
            echo "  - Verifying archive integrity..." && \
            if ! gzip -t "${GSTREAMER_FILE}" 2>/dev/null; then \
                echo "  ? ERROR: Archive is corrupted or not a valid gzip file!" && \
                exit 1; \
            fi && \
            echo "  - Extracting to /opt..." && \
            cd /opt && tar -xzf "/tmp/${GSTREAMER_FILE}" && \
            rm -f "/tmp/${GSTREAMER_FILE}" && \
            echo "  ? GStreamer bundle extracted to /opt" && \
            # Step 2: Download and install Python wheel package
            echo "[2/4] Downloading and installing Selkies GStreamer Python package..." && \
            WHL_FILE="selkies_gstreamer-${SELKIES_VERSION}-py3-none-any.whl" && \
            echo "  - File: ${WHL_FILE}" && \
            echo "  - URL: ${CDN_BASE_URL}/${WHL_FILE}" && \
            cd /tmp && \
            echo "  - Downloading file..." && \
            curl ${CURL_RETRY_OPTS} -fSL --progress-bar -w "HTTP Status: %{http_code}, Size: %{size_download} bytes\n" \
                -o "${WHL_FILE}" "${CDN_BASE_URL}/${WHL_FILE}" && \
            if [ ! -f "${WHL_FILE}" ]; then \
                echo "  ? ERROR: File was not downloaded!" && exit 1; \
            fi && \
            WHL_SIZE=$(stat -c%s "${WHL_FILE}" 2>/dev/null || stat -f%z "${WHL_FILE}" 2>/dev/null) && \
            echo "  - Downloaded file size: $((WHL_SIZE / 1024)) KB (${WHL_SIZE} bytes)" && \
            if [ ${WHL_SIZE} -lt 10000 ]; then \
                echo "  ? ERROR: File is too small (< 10 KB), probably download failed" && \
                cat "${WHL_FILE}" && \
                exit 1; \
            fi && \
            echo "  - Installing via pip3..." && \
            pip3 install --no-cache-dir --force-reinstall --ignore-installed idna "${WHL_FILE}" "websockets<14.0" && \
            rm -f "${WHL_FILE}" && \
            echo "  ? Python package installed" && \
            # Step 3: Download and extract Selkies GStreamer Web interface to /opt
            echo "[3/4] Downloading Selkies GStreamer Web interface..." && \
            WEB_FILE="selkies-gstreamer-web_v${SELKIES_VERSION}.tar.gz" && \
            echo "  - File: ${WEB_FILE}" && \
            echo "  - URL: ${CDN_BASE_URL}/${WEB_FILE}" && \
            cd /tmp && \
            echo "  - Downloading file..." && \
            curl ${CURL_RETRY_OPTS} -fSL --progress-bar -w "HTTP Status: %{http_code}, Size: %{size_download} bytes\n" \
                -o "${WEB_FILE}" "${CDN_BASE_URL}/${WEB_FILE}" && \
            if [ ! -f "${WEB_FILE}" ]; then \
                echo "  ? ERROR: File was not downloaded!" && exit 1; \
            fi && \
            WEB_SIZE=$(stat -c%s "${WEB_FILE}" 2>/dev/null || stat -f%z "${WEB_FILE}" 2>/dev/null) && \
            echo "  - Downloaded file size: $((WEB_SIZE / 1024)) KB (${WEB_SIZE} bytes)" && \
            echo "  - Extracting to /opt..." && \
            cd /opt && tar -xzf "/tmp/${WEB_FILE}" && \
            rm -f "/tmp/${WEB_FILE}" && \
            if [ -d "/opt/gst-web-react" ] && [ ! -d "/opt/gst-web" ]; then \
                echo "  - Renaming gst-web-react to gst-web..." && \
                mv /opt/gst-web-react /opt/gst-web; \
            fi && \
            echo "  ? Web interface extracted to /opt/gst-web" && \
            # Step 4: Download and install Selkies JS Interposer (using Ubuntu 22.04 version for compatibility with 24.04)
            echo "[4/4] Downloading and installing Selkies JS Interposer..." && \
            JS_UBUNTU_VERSION="${UBUNTU_VERSION}" && \
            if [ "${UBUNTU_VERSION}" = "24.04" ]; then \
                JS_UBUNTU_VERSION="22.04"; \
                echo "  - Note: Using Ubuntu 22.04 version for compatibility with 24.04"; \
            fi && \
            JS_FILE="selkies-js-interposer_v${SELKIES_VERSION}_ubuntu${JS_UBUNTU_VERSION}_${ARCH}.deb" && \
            echo "  - File: ${JS_FILE}" && \
            echo "  - URL: ${CDN_BASE_URL}/${JS_FILE}" && \
            cd /tmp && \
            echo "  - Downloading file..." && \
            curl ${CURL_RETRY_OPTS} -fSL --progress-bar -w "HTTP Status: %{http_code}, Size: %{size_download} bytes\n" \
                -o selkies-js-interposer.deb "${CDN_BASE_URL}/${JS_FILE}" && \
            if [ ! -f selkies-js-interposer.deb ]; then \
                echo "  ? ERROR: File was not downloaded!" && exit 1; \
            fi && \
            DEB_SIZE=$(stat -c%s selkies-js-interposer.deb 2>/dev/null || stat -f%z selkies-js-interposer.deb 2>/dev/null) && \
            echo "  - Downloaded file size: $((DEB_SIZE / 1024)) KB (${DEB_SIZE} bytes)" && \
            if [ ${DEB_SIZE} -lt 1000 ]; then \
                echo "  ? ERROR: File is too small (< 1 KB), probably download failed" && \
                cat selkies-js-interposer.deb && \
                exit 1; \
            fi && \
            echo "  - Installing package..." && \
            apt-get update && apt-get install --no-install-recommends -y ./selkies-js-interposer.deb && \
            rm -f selkies-js-interposer.deb && \
            echo "  ? JS Interposer installed" && \
            echo "======================================== " && \
            echo "? Selkies v${SELKIES_VERSION} installation completed successfully!" && \
            echo "======================================== "; \
        fi && \
        rm -rf /tmp/selkies && \
        apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*

# Copy and extract Warplay driver from host (optional)
# Place wp_drivers_v*.tar.gz file in install_to_docker/ directory before building
# Directory structure:
#   docker-selkies-egl-desktop/
#     ├── Dockerfile
#     └── install_to_docker/wp_drivers_v*.tar.gz
# If file is not found, this step will be skipped (driver is optional)
ARG INCLUDE_WARPLAY_DRIVER=true
RUN mkdir -pm755 /opt/wpcdrv
COPY install_to_docker/wp_drivers_v*.tar.gz /tmp/
RUN if [ "$INCLUDE_WARPLAY_DRIVER" = "true" ]; then \
        DRIVER_FILE=$(ls /tmp/wp_drivers_v*.tar.gz 2>/dev/null | head -n 1) && \
        if [ -n "$DRIVER_FILE" ] && [ -f "$DRIVER_FILE" ]; then \
            echo "Installing Warplay driver from $DRIVER_FILE..." && \
            cd /opt/wpcdrv && \
            tar -xzf "$DRIVER_FILE" --strip-components=1 && \
            rm -f /tmp/wp_drivers_v*.tar.gz && \
            chown -R 1000:1000 /opt/wpcdrv && \
            echo "Warplay driver installed successfully"; \
        else \
            echo "Warning: Warplay driver archive not found in install_to_docker/ directory." && \
            echo "  Place wp_drivers_v*.tar.gz file in install_to_docker/ before building." && \
            echo "  Or disable this step: docker build --build-arg INCLUDE_WARPLAY_DRIVER=false ." && \
            echo "  Expected: install_to_docker/wp_drivers_v*.tar.gz"; \
        fi; \
    else \
        echo "Skipping Warplay driver installation (INCLUDE_WARPLAY_DRIVER=false)"; \
    fi

#
# Install KasmVNC web interface; RustDesk removed
RUN KASMVNC_VERSION="$(curl -fsSL ${CURL_RETRY_OPTS} "https://api.github.com/repos/kasmtech/KasmVNC/releases/latest" | jq -r '.tag_name' | sed 's/[^0-9\.\-]*//g')" && \
    cd /tmp && curl -o kasmvncserver.deb -fsSL ${CURL_RETRY_OPTS} "https://github.com/kasmtech/KasmVNC/releases/download/v${KASMVNC_VERSION}/kasmvncserver_$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 | tr -d '\"')_${KASMVNC_VERSION}_$(dpkg --print-architecture).deb" && apt-get update && apt-get install --no-install-recommends -y ./kasmvncserver.deb libdatetime-perl && rm -f kasmvncserver.deb && \
    YQ_VERSION="$(curl -fsSL ${CURL_RETRY_OPTS} "https://api.github.com/repos/mikefarah/yq/releases/latest" | jq -r '.tag_name' | sed 's/[^0-9\.\-]*//g')" && \
    cd /tmp && curl -o yq -fsSL ${CURL_RETRY_OPTS} "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_$(dpkg --print-architecture)" && install ./yq /usr/bin/ && rm -f yq && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*

# Copy scripts and configurations used to start the container with `--chown=1000:1000`
COPY --chown=1000:1000 entrypoint.sh /etc/entrypoint.sh
RUN chmod -f 755 /etc/entrypoint.sh
COPY --chown=1000:1000 selkies-gstreamer-entrypoint.sh /etc/selkies-gstreamer-entrypoint.sh
RUN chmod -f 755 /etc/selkies-gstreamer-entrypoint.sh
COPY --chown=1000:1000 kasmvnc-entrypoint.sh /etc/kasmvnc-entrypoint.sh
RUN chmod -f 755 /etc/kasmvnc-entrypoint.sh
COPY --chown=1000:1000 supervisord.conf /etc/supervisord.conf
RUN chmod -f 755 /etc/supervisord.conf
# Copy wp-helpers directory to /opt/wp-helpers
COPY --chown=1000:1000 wp-helpers /opt/wp-helpers

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
