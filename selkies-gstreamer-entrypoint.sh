#!/bin/bash

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

set -e

# Wait for XDG_RUNTIME_DIR
until [ -d "${XDG_RUNTIME_DIR}" ]; do sleep 0.5; done

# Set default display
export DISPLAY="${DISPLAY:-:20}"
# PipeWire-Pulse server socket path
export PIPEWIRE_LATENCY="128/48000"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
export PIPEWIRE_RUNTIME_DIR="${PIPEWIRE_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/tmp}}"
export PULSE_RUNTIME_PATH="${PULSE_RUNTIME_PATH:-${XDG_RUNTIME_DIR:-/tmp}/pulse}"
export PULSE_SERVER="${PULSE_SERVER:-unix:${PULSE_RUNTIME_PATH:-${XDG_RUNTIME_DIR:-/tmp}/pulse}/native}"

# Export environment variables required for Selkies
export GST_DEBUG="${GST_DEBUG:-*:2}"
export GSTREAMER_PATH=/opt/gstreamer

# Source environment for GStreamer
. /opt/gstreamer/gst-env

export SELKIES_ENCODER="${SELKIES_ENCODER:-x264enc}"
export SELKIES_ENABLE_RESIZE="${SELKIES_ENABLE_RESIZE:-false}"

# Extract NVRTC dependency, https://developer.download.nvidia.com/compute/cuda/redist/cuda_nvrtc/LICENSE.txt
if command -v nvidia-smi &> /dev/null && nvidia-smi >/dev/null 2>&1; then
  NVRTC_DEST_PREFIX="${NVRTC_DEST_PREFIX-/opt/gstreamer}"
  CUDA_DRIVER_SYSTEM="$(nvidia-smi --version | grep 'CUDA Version' | cut -d: -f2 | tr -d ' ')"
  NVRTC_ARCH="${NVRTC_ARCH-$(dpkg --print-architecture | sed -e 's/arm64/sbsa/' -e 's/ppc64el/ppc64le/' -e 's/i.*86/x86/' -e 's/amd64/x86_64/' -e 's/unknown/x86_64/')}"
  # TEMPORARY: Cap CUDA version to 12.9 if the detected version is 13.0 or higher for NVRTC compatibility, https://gitlab.freedesktop.org/gstreamer/gstreamer/-/issues/4655
  if [ -n "${CUDA_DRIVER_SYSTEM}" ]; then
    CUDA_MAJOR_VERSION=$(echo "${CUDA_DRIVER_SYSTEM}" | cut -d. -f1)
    if [ "${CUDA_MAJOR_VERSION}" -ge 13 ]; then
      CUDA_DRIVER_SYSTEM="12.9"
    fi
  fi
  NVRTC_URL="https://developer.download.nvidia.com/compute/cuda/redist/cuda_nvrtc/linux-${NVRTC_ARCH}/"
  NVRTC_ARCHIVE="$(curl -fsSL "${NVRTC_URL}" | grep -oP "(?<=href=')cuda_nvrtc-linux-${NVRTC_ARCH}-${CUDA_DRIVER_SYSTEM}\.[0-9]+-archive\.tar\.xz" | sort -V | tail -n 1)"
  if [ -z "${NVRTC_ARCHIVE}" ]; then
    FALLBACK_VERSION="${CUDA_DRIVER_SYSTEM}.0"
    NVRTC_ARCHIVE=$((curl -fsSL "${NVRTC_URL}" | grep -oP "(?<=href=')cuda_nvrtc-linux-${NVRTC_ARCH}-.*?\.tar\.xz" ; \
    echo "cuda_nvrtc-linux-${NVRTC_ARCH}-${FALLBACK_VERSION}-archive.tar.xz") | \
    sort -V | grep -B 1 --fixed-strings "${FALLBACK_VERSION}" | head -n 1)
  fi
  if [ -z "${NVRTC_ARCHIVE}" ]; then
      echo "ERROR: Could not find a compatible NVRTC archive." >&2
  fi
  echo "Selected NVRTC archive: ${NVRTC_ARCHIVE}"
  NVRTC_LIB_ARCH="$(dpkg --print-architecture | sed -e 's/arm64/aarch64-linux-gnu/' -e 's/armhf/arm-linux-gnueabihf/' -e 's/riscv64/riscv64-linux-gnu/' -e 's/ppc64el/powerpc64le-linux-gnu/' -e 's/s390x/s390x-linux-gnu/' -e 's/i.*86/i386-linux-gnu/' -e 's/amd64/x86_64-linux-gnu/' -e 's/unknown/x86_64-linux-gnu/')"
  cd /tmp && curl -fsSL "${NVRTC_URL}${NVRTC_ARCHIVE}" | tar -xJf - -C /tmp && mv -f cuda_nvrtc* cuda_nvrtc && cd cuda_nvrtc/lib && chmod -f 755 libnvrtc* && rm -f "${NVRTC_DEST_PREFIX}/lib/${NVRTC_LIB_ARCH}/"libnvrtc* && mv -f libnvrtc* "${NVRTC_DEST_PREFIX}/lib/${NVRTC_LIB_ARCH}/" && cd /tmp && rm -rf /tmp/cuda_nvrtc && cd "${HOME}"
fi

# Wait for X server to start
echo 'Waiting for X Socket' && until [ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; do sleep 0.5; done && echo 'X Server is ready'

# Configure NGINX
if [ "$(echo ${SELKIES_ENABLE_BASIC_AUTH} | tr '[:upper:]' '[:lower:]')" != "false" ]; then htpasswd -bcm "${XDG_RUNTIME_DIR}/.htpasswd" "${SELKIES_BASIC_AUTH_USER:-${USER}}" "${SELKIES_BASIC_AUTH_PASSWORD:-${PASSWD}}"; fi
# echo "# Selkies NGINX Configuration
# server {
#     access_log /dev/stdout;
#     error_log /dev/stderr;
#     listen ${NGINX_PORT:-8080} $(if [ \"$(echo ${SELKIES_ENABLE_HTTPS} | tr '[:upper:]' '[:lower:]')\" = \"true\" ]; then echo -n "ssl"; fi);
#     listen [::]:${NGINX_PORT:-8080} $(if [ \"$(echo ${SELKIES_ENABLE_HTTPS} | tr '[:upper:]' '[:lower:]')\" = \"true\" ]; then echo -n "ssl"; fi);
#     ssl_certificate ${SELKIES_HTTPS_CERT-/etc/ssl/certs/ssl-cert-snakeoil.pem};
#     ssl_certificate_key ${SELKIES_HTTPS_KEY-/etc/ssl/private/ssl-cert-snakeoil.key};
#     $(if [ \"$(echo ${SELKIES_ENABLE_BASIC_AUTH} | tr '[:upper:]' '[:lower:]')\" != \"false\" ]; then echo "auth_basic \"Selkies\";"; echo -n "    auth_basic_user_file ${XDG_RUNTIME_DIR}/.htpasswd;"; fi)

#     # CORS headers for dev/proxy scenarios
#     add_header Access-Control-Allow-Origin "*" always;
#     add_header Access-Control-Allow-Methods "GET, POST, OPTIONS, PUT, DELETE" always;
#     add_header Access-Control-Allow-Headers "*,x-auth-user,authorization,content-type" always;
#     add_header Access-Control-Max-Age 86400 always;
#     if ($request_method = OPTIONS) {
#         add_header Content-Length 0;
#         add_header Content-Type text/plain;
#         return 204;
#     }

#     location / {
#         root /opt/gst-web/;
#         index  index.html index.htm;
#     }

#     location /health {
#         proxy_http_version      1.1;
#         proxy_read_timeout      3600s;
#         proxy_send_timeout      3600s;
#         proxy_connect_timeout   3600s;
#         proxy_buffering         off;

#         client_max_body_size    10M;

#         proxy_pass http$(if [ \"$(echo ${SELKIES_ENABLE_HTTPS} | tr '[:upper:]' '[:lower:]')\" = \"true\" ]; then echo -n "s"; fi)://localhost:${SELKIES_PORT:-8081};
#     }

#     location /ws {
#         proxy_set_header        Upgrade \$http_upgrade;
#         proxy_set_header        Connection \"upgrade\";

#         proxy_set_header        Host \$host;
#         proxy_set_header        X-Real-IP \$remote_addr;
#         proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
#         proxy_set_header        X-Forwarded-Proto \$scheme;

#         proxy_http_version      1.1;
#         proxy_read_timeout      3600s;
#         proxy_send_timeout      3600s;
#         proxy_connect_timeout   3600s;
#         proxy_buffering         off;

#         client_max_body_size    10M;

#         proxy_pass http$(if [ \"$(echo ${SELKIES_ENABLE_HTTPS} | tr '[:upper:]' '[:lower:]')\" = \"true\" ]; then echo -n "s"; fi)://localhost:${SELKIES_PORT:-8081};
#     }
#     location /turn {
#         proxy_http_version      1.1;
#         proxy_read_timeout      3600s;
#         proxy_send_timeout      3600s;
#         proxy_connect_timeout   3600s;
#         proxy_buffering         off;

#         client_max_body_size    10M;

#         proxy_pass http$(if [ \"$(echo ${SELKIES_ENABLE_HTTPS} | tr '[:upper:]' '[:lower:]')\" = \"true\" ]; then echo -n "s"; fi)://localhost:${SELKIES_PORT:-8081};
#     }
#     location /webrtc/signalling {
#         proxy_set_header        Upgrade \$http_upgrade;
#         proxy_set_header        Connection \"upgrade\";

#         proxy_set_header        Host \$host;
#         proxy_set_header        X-Real-IP \$remote_addr;
#         proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
#         proxy_set_header        X-Forwarded-Proto \$scheme;

#         proxy_http_version      1.1;
#         proxy_read_timeout      3600s;
#         proxy_send_timeout      3600s;
#         proxy_connect_timeout   3600s;
#         proxy_buffering         off;

#         client_max_body_size    10M;

#         proxy_pass http$(if [ \"$(echo ${SELKIES_ENABLE_HTTPS} | tr '[:upper:]' '[:lower:]')\" = \"true\" ]; then echo -n "s"; fi)://localhost:${SELKIES_PORT:-8081};
#     }

#     location /metrics {
#         proxy_http_version      1.1;
#         proxy_read_timeout      3600s;
#         proxy_send_timeout      3600s;
#         proxy_connect_timeout   3600s;
#         proxy_buffering         off;

#         client_max_body_size    10M;

#         proxy_pass http$(if [ \"$(echo ${SELKIES_ENABLE_HTTPS} | tr '[:upper:]' '[:lower:]')\" = \"true\" ]; then echo -n "s"; fi)://localhost:${SELKIES_METRICS_HTTP_PORT:-9081};
#     }

#     error_page 500 502 503 504 /50x.html;
#     location = /50x.html {
#         root /opt/gst-web/;
#     }
# }" | tee /etc/nginx/sites-available/default > /dev/null

# Clear the cache registry
rm -rf "${HOME}/.cache/gstreamer-1.0"

# Start the Selkies WebRTC HTML5 remote desktop application
selkies-gstreamer \
    --addr="0.0.0.0" \
    --port="${SELKIES_PORT:-8080}" \
    --enable_basic_auth="false" \
    --enable_metrics_http="true" \
    --metrics_http_port="${SELKIES_METRICS_HTTP_PORT:-9081}" \
    $@
