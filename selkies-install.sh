#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${STATE_DIR:-/opt/selkies-install}"
mkdir -p "${STATE_DIR}"
mkdir -p "${STATE_DIR}/cache"

SELKIES_SOURCE="${SELKIES_SOURCE:-cdn}" # cdn|local

UBUNTU_VERSION="$(. /etc/os-release && echo "${VERSION_ID}")"
ARCH="$(dpkg --print-architecture)"

fallback_releases=("${UBUNTU_VERSION}" "22.04" "20.04")

read_state() {
  local key="$1"
  cat "${STATE_DIR}/${key}"
}

write_state() {
  local key="$1"
  local value="$2"
  printf '%s' "${value}" >"${STATE_DIR}/${key}"
}

detect_local_dir() {
  local base="/tmp/install_to_docker"
  local candidate="${base}/selkies"
  if [ -d "${candidate}" ]; then
    for rel in "${fallback_releases[@]}"; do
      if ls -1 "${candidate}/gstreamer-selkies_gpl_v"*"_ubuntu${rel}_${ARCH}.tar.gz" >/dev/null 2>&1; then
        echo "${candidate}"
        return 0
      fi
    done
  fi
  echo "${base}"
}

detect_local_version() {
  local local_dir="$1"

  # Try to infer the Selkies version from any present artifact.
  # Prefer wheel/web, then deb/tar.
  local f v

  f="$(ls -1 "${local_dir}/selkies_gstreamer-"*.whl 2>/dev/null | head -n 1 || true)"
  if [ -n "${f}" ]; then
    v="$(basename "${f}")"
    v="${v#selkies_gstreamer-}"
    v="${v%-py3-none-any.whl}"
    if [ -n "${v}" ]; then echo "${v}"; return 0; fi
  fi

  f="$(ls -1 "${local_dir}/selkies-gstreamer-web_v"*.tar.gz 2>/dev/null | head -n 1 || true)"
  if [ -n "${f}" ]; then
    v="$(basename "${f}")"
    v="${v#selkies-gstreamer-web_v}"
    v="${v%.tar.gz}"
    if [ -n "${v}" ]; then echo "${v}"; return 0; fi
  fi

  f="$(ls -1 "${local_dir}/selkies-js-interposer_v"*"_ubuntu"*".deb" 2>/dev/null | head -n 1 || true)"
  if [ -n "${f}" ]; then
    v="$(basename "${f}")"
    v="${v#selkies-js-interposer_v}"
    v="${v%%_ubuntu*}"
    if [ -n "${v}" ]; then echo "${v}"; return 0; fi
  fi

  f="$(ls -1 "${local_dir}/gstreamer-selkies_gpl_v"*"_ubuntu"*".tar.gz" 2>/dev/null | head -n 1 || true)"
  if [ -n "${f}" ]; then
    v="$(basename "${f}")"
    v="${v#gstreamer-selkies_gpl_v}"
    v="${v%%_ubuntu*}"
    if [ -n "${v}" ]; then echo "${v}"; return 0; fi
  fi

  return 1
}

apply_copy_overlay_if_present() {
  local local_dir="$1"
  local copy_dir="${local_dir}/copy_to_docker"
  if [ ! -d "${copy_dir}" ]; then
    copy_dir="/tmp/install_to_docker/copy_to_docker"
  fi
  if [ -d "${copy_dir}" ] && [ -n "$(ls -A "${copy_dir}" 2>/dev/null || true)" ]; then
    echo "Applying ${copy_dir} overlay to /"
    cp -a "${copy_dir}/." /
  fi
}

require_cmd() {
  local c="$1"
  command -v "${c}" >/dev/null 2>&1 || { echo "ERROR: missing command: ${c}" >&2; exit 1; }
}

init_cdn() {
  require_cmd curl
  require_cmd jq

  echo "Fetching latest Selkies version from CDN..."
  local v
  v="$(curl -fsSL ${CURL_RETRY_OPTS:-} "https://cdn.warplay.cloud/drivers/linux/system/selkies/releases/latest" | jq -r '.tag_name')"
  if [ -z "${v}" ] || [ "${v}" = "null" ]; then
    echo "ERROR: Failed to fetch Selkies version from CDN" >&2
    exit 1
  fi
  write_state selkies_version "${v}"
  write_state cdn_base_url "https://cdn.warplay.cloud/drivers/linux/system/selkies/releases/download/v${v}"
}

init_local() {
  local local_dir version
  local_dir="$(detect_local_dir)"
  version="$(detect_local_version "${local_dir}" || true)"
  if [ -z "${version}" ]; then
    echo "ERROR: SELKIES_SOURCE=local but can't detect Selkies version from artifacts in ${local_dir}" >&2
    echo "  Provide at least one of:" >&2
    echo "    - selkies_gstreamer-<version>-py3-none-any.whl" >&2
    echo "    - selkies-gstreamer-web_v<version>.tar.gz" >&2
    echo "    - selkies-js-interposer_v<version>_ubuntu<release>_<arch>.deb" >&2
    echo "    - gstreamer-selkies_gpl_v<version>_ubuntu<release>_<arch>.tar.gz" >&2
    exit 1
  fi
  write_state selkies_version "${version}"
  write_state cdn_base_url "https://cdn.warplay.cloud/drivers/linux/system/selkies/releases/download/v${version}"
  echo "Local Selkies version: ${version}"
  echo "CDN Base URL (fallback): $(read_state cdn_base_url)"
}

init() {
  echo "========================================"
  echo "Selkies source: ${SELKIES_SOURCE}"
  echo "Ubuntu Version: ${UBUNTU_VERSION}"
  echo "Architecture: ${ARCH}"
  echo "========================================"

  write_state ubuntu_version "${UBUNTU_VERSION}"
  write_state arch "${ARCH}"

  if [ "${SELKIES_SOURCE}" = "cdn" ]; then
    init_cdn
    echo "CDN Base URL: $(read_state cdn_base_url)"
  elif [ "${SELKIES_SOURCE}" = "local" ]; then
    init_local
  else
    echo "ERROR: SELKIES_SOURCE must be 'cdn' or 'local' (got '${SELKIES_SOURCE}')" >&2
    exit 1
  fi
}

install_gstreamer_local() {
  local local_dir
  local_dir="$(detect_local_dir)"
  apply_copy_overlay_if_present "${local_dir}"

  echo "[1/4] Installing local GStreamer Selkies GPL bundle..."
  local f=""
  for rel in "${fallback_releases[@]}"; do
    f="$(ls -1 "${local_dir}/gstreamer-selkies_gpl_v"*"_ubuntu${rel}_${ARCH}.tar.gz" 2>/dev/null | head -n 1 || true)"
    if [ -n "${f}" ]; then
      echo "  - Using Ubuntu ${rel} bundle: $(basename "${f}")"
      break
    fi
  done
  if [ -z "${f}" ]; then
    echo "No local GStreamer bundle found in ${local_dir}, falling back to CDN download into image cache..."
    install_gstreamer_cdn
    return 0
  fi
  gzip -t "${f}" >/dev/null 2>&1 || { echo "ERROR: corrupted gzip: ${f}" >&2; exit 1; }
  tar -xzf "${f}" -C /opt
}

install_gstreamer_cdn() {
  local base_url
  base_url="$(read_state cdn_base_url)"
  local v
  v="$(read_state selkies_version)"

  echo "[1/4] Downloading GStreamer Selkies GPL bundle..."
  local chosen=""
  for rel in "${fallback_releases[@]}"; do
    local name="gstreamer-selkies_gpl_v${v}_ubuntu${rel}_${ARCH}.tar.gz"
    local cached="${STATE_DIR}/cache/${name}"
    echo "  - Trying: ${name}"
    if [ -f "${cached}" ] && gzip -t "${cached}" >/dev/null 2>&1; then
      chosen="${cached}"
      echo "  - Using cached bundle (Ubuntu ${rel})"
      break
    fi
    if curl ${CURL_RETRY_OPTS:-} -fSL --progress-bar -o "${cached}" "${base_url}/${name}"; then
      if gzip -t "${cached}" >/dev/null 2>&1; then
        chosen="${cached}"
        echo "  - Downloaded and cached (Ubuntu ${rel})"
        break
      fi
      rm -f "${cached}" || true
    fi
  done
  if [ -z "${chosen}" ] || [ ! -f "${chosen}" ]; then
    echo "ERROR: failed to download any compatible GStreamer bundle from CDN" >&2
    exit 1
  fi
  tar -xzf "${chosen}" -C /opt
}

install_gstreamer() {
  if [ "${SELKIES_SOURCE}" = "local" ]; then
    install_gstreamer_local
  else
    install_gstreamer_cdn
  fi
}

install_python_local() {
  local local_dir
  local_dir="$(detect_local_dir)"

  echo "[2/4] Installing local Selkies GStreamer Python package..."
  local whl
  whl="$(ls -1 "${local_dir}/selkies_gstreamer-"*.whl 2>/dev/null | sort -V | tail -n 1 || true)"
  if [ -z "${whl}" ]; then
    echo "ERROR: Missing local Python wheel in ${local_dir}" >&2
    exit 1
  fi
  pip3 install --no-cache-dir --force-reinstall --ignore-installed idna "${whl}" "websockets<14.0"
}

install_python_cdn() {
  local base_url v
  base_url="$(read_state cdn_base_url)"
  v="$(read_state selkies_version)"

  echo "[2/4] Downloading and installing Selkies GStreamer Python package..."
  cd /tmp
  local whl="selkies_gstreamer-${v}-py3-none-any.whl"
  curl ${CURL_RETRY_OPTS:-} -fSL --progress-bar -o "${whl}" "${base_url}/${whl}"
  pip3 install --no-cache-dir --force-reinstall --ignore-installed idna "${whl}" "websockets<14.0"
  rm -f "${whl}" || true
}

install_python() {
  if [ "${SELKIES_SOURCE}" = "local" ]; then
    install_python_local
  else
    install_python_cdn
  fi
}

install_web_local() {
  local local_dir
  local_dir="$(detect_local_dir)"

  echo "[3/4] Installing local Selkies GStreamer Web interface..."
  local web
  web="$(ls -1 "${local_dir}/selkies-gstreamer-web_v"*.tar.gz 2>/dev/null | sort -V | tail -n 1 || true)"
  if [ -z "${web}" ]; then
    echo "ERROR: Missing local web tarball in ${local_dir}" >&2
    exit 1
  fi
  tar -xzf "${web}" -C /opt
  if [ -d "/opt/gst-web-react" ] && [ ! -d "/opt/gst-web" ]; then
    mv /opt/gst-web-react /opt/gst-web
  fi
}

install_web_cdn() {
  local base_url v
  base_url="$(read_state cdn_base_url)"
  v="$(read_state selkies_version)"

  echo "[3/4] Downloading Selkies GStreamer Web interface..."
  cd /tmp
  local web="selkies-gstreamer-web_v${v}.tar.gz"
  curl ${CURL_RETRY_OPTS:-} -fSL --progress-bar -o "${web}" "${base_url}/${web}"
  tar -xzf "${web}" -C /opt
  rm -f "${web}" || true
  if [ -d "/opt/gst-web-react" ] && [ ! -d "/opt/gst-web" ]; then
    mv /opt/gst-web-react /opt/gst-web
  fi
}

install_web() {
  if [ "${SELKIES_SOURCE}" = "local" ]; then
    install_web_local
  else
    install_web_cdn
  fi
}

install_js_local() {
  local local_dir
  local_dir="$(detect_local_dir)"

  echo "[4/4] Installing local Selkies JS Interposer..."
  local deb=""
  for rel in "${fallback_releases[@]}"; do
    deb="$(ls -1 "${local_dir}/selkies-js-interposer_v"*"_ubuntu${rel}_${ARCH}.deb" 2>/dev/null | head -n 1 || true)"
    if [ -n "${deb}" ]; then
      echo "  - Using Ubuntu ${rel} JS interposer: $(basename "${deb}")"
      break
    fi
  done
  if [ -z "${deb}" ]; then
    echo "ERROR: Missing local JS interposer in ${local_dir}" >&2
    exit 1
  fi
  apt-get update
  apt-get install --no-install-recommends -y "${deb}"
}

install_js_cdn() {
  local base_url v
  base_url="$(read_state cdn_base_url)"
  v="$(read_state selkies_version)"

  echo "[4/4] Downloading and installing Selkies JS Interposer..."
  cd /tmp
  local chosen=""
  for rel in "${fallback_releases[@]}"; do
    local name="selkies-js-interposer_v${v}_ubuntu${rel}_${ARCH}.deb"
    echo "  - Trying: ${name}"
    if curl ${CURL_RETRY_OPTS:-} -fSL --progress-bar -o selkies-js-interposer.deb "${base_url}/${name}"; then
      chosen="${name}"
      echo "  - Selected Ubuntu ${rel} JS interposer"
      break
    fi
    rm -f selkies-js-interposer.deb || true
  done
  if [ ! -f selkies-js-interposer.deb ]; then
    echo "ERROR: failed to download JS interposer from CDN" >&2
    exit 1
  fi
  apt-get update
  apt-get install --no-install-recommends -y ./selkies-js-interposer.deb
  rm -f selkies-js-interposer.deb || true
}

install_js() {
  if [ "${SELKIES_SOURCE}" = "local" ]; then
    install_js_local
  else
    install_js_cdn
  fi
}

cleanup() {
  apt-get clean
  rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /var/tmp/*
  rm -rf /tmp/* || true
}

cmd="${1:-}"
case "${cmd}" in
  init) init ;;
  gstreamer) install_gstreamer ;;
  python) install_python ;;
  web) install_web ;;
  js) install_js ;;
  cleanup) cleanup ;;
  *)
    echo "Usage: $0 {init|gstreamer|python|web|js|cleanup}" >&2
    exit 2
    ;;
esac
