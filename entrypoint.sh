#!/bin/bash

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

set -e

trap "echo TRAPed signal" HUP INT QUIT TERM

# Startup mode:
# - primary: start our own Xvfb/KDE (default)
# - secondary: use host X (expect DISPLAY mounted/available), don't start Xvfb here
export MODE="${MODE:-primary}"

# Wait for XDG_RUNTIME_DIR
until [ -d "${XDG_RUNTIME_DIR}" ]; do sleep 0.5; done
# Make user directory owned by the default user
chown -f "$(id -nu):$(id -ng)" ~ || sudo-root chown -f "$(id -nu):$(id -ng)" ~ || chown -R -f -h --no-preserve-root "$(id -nu):$(id -ng)" ~ || sudo-root chown -R -f -h --no-preserve-root "$(id -nu):$(id -ng)" ~ || echo 'Failed to change user directory permissions, there may be permission issues'
# Change operating system password to environment variable
(echo "${PASSWD}"; echo "${PASSWD}";) | sudo passwd "$(id -nu)" || (echo "mypasswd"; echo "${PASSWD}"; echo "${PASSWD}";) | passwd "$(id -nu)" || echo 'Password change failed, using default password'
# Remove directories to make sure the desktop environment starts (skip for host-X mode)
if [ "${MODE}" != "secondary" ]; then
  rm -rf /tmp/.X* ~/.cache || echo 'Failed to clean X11 paths'
fi
# Change time zone from environment variable
ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime && echo "${TZ}" | tee /etc/timezone > /dev/null || echo 'Failed to set timezone'
# Add Lutris directories to path
export PATH="${PATH:+${PATH}:}/usr/local/games:/usr/games"
# Add LibreOffice to library path
export LD_LIBRARY_PATH="/usr/lib/libreoffice/program${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

# Configure joystick interposer
export SELKIES_INTERPOSER='/usr/$LIB/selkies_joystick_interposer.so'
export LD_PRELOAD="${SELKIES_INTERPOSER}${LD_PRELOAD:+:${LD_PRELOAD}}"
export SDL_JOYSTICK_DEVICE=/dev/input/js0
mkdir -pm1777 /dev/input || sudo-root mkdir -pm1777 /dev/input || echo 'Failed to create joystick interposer directory'
touch /dev/input/js0 /dev/input/js1 /dev/input/js2 /dev/input/js3 || sudo-root touch /dev/input/js0 /dev/input/js1 /dev/input/js2 /dev/input/js3 || echo 'Failed to create joystick interposer devices'
chmod 777 /dev/input/js* || sudo-root chmod 777 /dev/input/js* || echo 'Failed to change permission for joystick interposer devices'

# Start udevd for libudev consumers (Firefox Gamepad API)
if command -v udevadm >/dev/null 2>&1; then
  UDEVD_BIN=""
  if [ -x /usr/lib/systemd/systemd-udevd ]; then
    UDEVD_BIN="/usr/lib/systemd/systemd-udevd"
  elif command -v systemd-udevd >/dev/null 2>&1; then
    UDEVD_BIN="systemd-udevd"
  elif command -v udevd >/dev/null 2>&1; then
    UDEVD_BIN="udevd"
  fi
  if [ -n "${UDEVD_BIN}" ]; then
    mkdir -pm755 /run/udev || sudo-root mkdir -pm755 /run/udev || echo 'Failed to create /run/udev'
    sudo-root "${UDEVD_BIN}" --daemon || "${UDEVD_BIN}" --daemon || echo 'Failed to start udevd'
    udevadm trigger --action=add || sudo-root udevadm trigger --action=add || echo 'Failed to trigger udev'
    udevadm settle || sudo-root udevadm settle || echo 'Failed to settle udev'
  else
    echo 'udevd binary not found, skipping udev startup'
  fi
fi

# Set default display
export DISPLAY="${DISPLAY:-:20}"
# PipeWire-Pulse server socket path
export PIPEWIRE_LATENCY="128/48000"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
export PIPEWIRE_RUNTIME_DIR="${PIPEWIRE_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/tmp}}"
export PULSE_RUNTIME_PATH="${PULSE_RUNTIME_PATH:-${XDG_RUNTIME_DIR:-/tmp}/pulse}"
export PULSE_SERVER="${PULSE_SERVER:-unix:${PULSE_RUNTIME_PATH:-${XDG_RUNTIME_DIR:-/tmp}/pulse}/native}"

# Run user init scripts (~ /init.d/*.sh) on container startup
# This is meant for "doinstall" without docker exec after recreation.
if [ "${INITD_SKIP:-false}" != "true" ] && [ -d "${HOME}/init.d" ]; then
  for f in "${HOME}/init.d/"*.sh; do
    [ -e "$f" ] || continue
    echo "Running init script: $f"
    if [ "${INITD_TRACE:-false}" = "true" ]; then
      bash -x "$f"
    else
      bash "$f"
    fi
  done
fi

if [ -z "$(ldconfig -N -v $(sed 's/:/ /g' <<< $LD_LIBRARY_PATH) 2>/dev/null | grep 'libEGL_nvidia.so.0')" ] || [ -z "$(ldconfig -N -v $(sed 's/:/ /g' <<< $LD_LIBRARY_PATH) 2>/dev/null | grep 'libGLX_nvidia.so.0')" ]; then
  # Install NVIDIA userspace driver components including X graphic libraries, keep contents same between docker-selkies-glx-desktop and docker-selkies-egl-desktop
  export NVIDIA_DRIVER_ARCH="$(dpkg --print-architecture | sed -e 's/arm64/aarch64/' -e 's/armhf/32bit-ARM/' -e 's/i.*86/x86/' -e 's/amd64/x86_64/' -e 's/unknown/x86_64/')"
  if [ -z "${NVIDIA_DRIVER_VERSION}" ]; then
    # Driver version is provided by the kernel through the container toolkit, prioritize kernel driver version if available
    if [ -f "/proc/driver/nvidia/version" ]; then
      export NVIDIA_DRIVER_VERSION="$(head -n1 </proc/driver/nvidia/version | awk '{for(i=1;i<=NF;i++) if ($i ~ /^[0-9]+\.[0-9\.]+/) {print $i; exit}}')"
    elif command -v nvidia-smi >/dev/null 2>&1; then
      # Use NVIDIA-SMI when not available
      export NVIDIA_DRIVER_VERSION="$(nvidia-smi --version | grep 'DRIVER version' | cut -d: -f2 | tr -d ' ')"
    else
      echo 'Failed to find NVIDIA GPU driver version, container will likely not start because of no NVIDIA container toolkit or NVIDIA GPU driver present'
    fi
  fi
  cd /tmp
  # If version is different, new installer will overwrite the existing components
  if [ ! -f "/tmp/NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" ]; then
    # Check multiple sources in order to probe both consumer and datacenter driver versions
    curl -fsSL -O "https://international.download.nvidia.com/XFree86/Linux-${NVIDIA_DRIVER_ARCH}/${NVIDIA_DRIVER_VERSION}/NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" || curl -fsSL -O "https://international.download.nvidia.com/tesla/${NVIDIA_DRIVER_VERSION}/NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" || echo 'Failed NVIDIA GPU driver download'
  fi
  if [ -f "/tmp/NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" ]; then
    # Extract installer before installing
    rm -rf "NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}"
    sh "NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" -x
    cd "NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}"
    # Run NVIDIA driver installation without the kernel modules and host components
    sudo ./nvidia-installer --silent \
                      --no-kernel-module \
                      --install-compat32-libs \
                      --no-nouveau-check \
                      --no-nvidia-modprobe \
                      --no-systemd \
                      --no-rpms \
                      --no-backup \
                      --no-check-for-alternate-installs
    rm -rf /tmp/NVIDIA* && cd ~
  else
    echo 'Unless using non-NVIDIA GPUs, container will likely not work correctly'
  fi
fi

# Run Xvfb server with required extensions
if [ "${MODE}" != "secondary" ]; then
  /usr/bin/Xvfb "${DISPLAY}" -screen 0 "8192x4096x${DISPLAY_CDEPTH}" -dpi "${DISPLAY_DPI}" +extension "COMPOSITE" +extension "DAMAGE" +extension "GLX" +extension "RANDR" +extension "RENDER" +extension "MIT-SHM" +extension "XFIXES" +extension "XTEST" +iglx +render -nolisten "tcp" -ac -noreset -shmem &
fi

# Wait for X server to start
echo 'Waiting for X Socket' && until [ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; do sleep 0.5; done && echo 'X Server is ready'

# Resize the screen to the provided size
if [ "${MODE}" != "secondary" ]; then
  /usr/local/bin/selkies-gstreamer-resize "${DISPLAY_SIZEW}x${DISPLAY_SIZEH}"
fi

# Use VirtualGL to run the KDE desktop environment with OpenGL if the GPU is available, otherwise use OpenGL with llvmpipe
export XDG_SESSION_ID="${DISPLAY#*:}"
export QT_LOGGING_RULES="${QT_LOGGING_RULES:-*.debug=false;qt.qpa.*=false}"
if [ -n "$(nvidia-smi --query-gpu=uuid --format=csv,noheader | head -n1)" ] || [ -n "$(ls -A /dev/dri 2>/dev/null)" ]; then
  export VGL_FPS="${DISPLAY_REFRESH}"
  /usr/bin/vglrun -d "${VGL_DISPLAY:-egl}" +wm /usr/bin/dbus-launch --exit-with-session /usr/bin/startplasma-x11 &
else
  /usr/bin/dbus-launch --exit-with-session /usr/bin/startplasma-x11 &
fi

# Start Fcitx input method framework
/usr/bin/fcitx &

# Add custom processes right below this line, or within `supervisord.conf` to perform service management similar to systemd

# Start Steam if marker file exists
if [ -e "/opt/startup/steam-native" ]; then
    steam &
fi
echo "Session Running. Press [Return] to exit."
read
