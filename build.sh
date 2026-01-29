#!/usr/bin/env bash
set -euo pipefail

#
# Build Selkies artifacts + build docker-selkies-egl-desktop image using SELKIES_SOURCE=local.
#
# Usage:
#   ./build.sh
#
# Optional env:
#   SELKIES_DIR=../selkies
#   INSTALL_DIR=./install_to_docker
#   BUILD_GSTREAMER=false
#   GSTREAMER_BUNDLE_SOURCE=auto
#   BUILD_CONTROL=true
#   SELKIES_SOURCE=local
#   INSTALL_KASMVNC=false
#   CACHE_BREAKER="$(date +%Y%m%d%H%M%S)"
#   DOCKERFILE=Dockerfile
#   IMAGE_TAG=selkies-egl:local
#   DOCKER_IMAGES=true
#   DOCKER_RM_CONTAINER=egl
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELKIES_DIR="${SELKIES_DIR:-${SCRIPT_DIR}/../selkies}"
INSTALL_DIR="${INSTALL_DIR:-${SCRIPT_DIR}/install_to_docker}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
IMAGE_TAG="${IMAGE_TAG:-selkies-egl:local}"

SELKIES_SOURCE="${SELKIES_SOURCE:-local}"
INSTALL_KASMVNC="${INSTALL_KASMVNC:-false}"
CACHE_BREAKER="${CACHE_BREAKER:-$(date +%Y%m%d%H%M%S)}"
DOCKER_IMAGES="${DOCKER_IMAGES:-true}"
DOCKER_RM_CONTAINER="${DOCKER_RM_CONTAINER:-egl}"

GSTREAMER_BUNDLE_SOURCE="${GSTREAMER_BUNDLE_SOURCE:-auto}"
BUILD_GSTREAMER="${BUILD_GSTREAMER:-false}"
BUILD_CONTROL="${BUILD_CONTROL:-true}"

echo "[build] selkies dir: ${SELKIES_DIR}"
echo "[build] install dir: ${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"

echo "[build] building selkies artifacts..."
(
  cd "${SELKIES_DIR}"
  chmod +x ./build.sh
  GSTREAMER_BUNDLE_SOURCE="${GSTREAMER_BUNDLE_SOURCE}" \
  BUILD_GSTREAMER="${BUILD_GSTREAMER}" \
  BUILD_CONTROL="${BUILD_CONTROL}" \
  ./build.sh
)

echo "[build] copying artifacts into install_to_docker/ ..."
# GStreamer bundle may be pre-seeded already; copy only if present, don't overwrite.
if ls "${SELKIES_DIR}/dist"/gstreamer-selkies_gpl_v*.tar.gz >/dev/null 2>&1; then
  cp -n "${SELKIES_DIR}/dist"/gstreamer-selkies_gpl_v*.tar.gz "${INSTALL_DIR}/"
else
  echo "[build] no GStreamer bundle in selkies/dist (ok if already present in install_to_docker/)"
fi

cp "${SELKIES_DIR}/dist"/selkies_gstreamer-*.whl "${INSTALL_DIR}/"
cp "${SELKIES_DIR}/dist"/selkies-gstreamer-web_v*.tar.gz "${INSTALL_DIR}/"

# JS interposer is optional.
if ls "${SELKIES_DIR}/dist"/selkies-js-interposer_v*.deb >/dev/null 2>&1; then
  cp "${SELKIES_DIR}/dist"/selkies-js-interposer_v*.deb "${INSTALL_DIR}/"
else
  echo "[build] no JS interposer deb in selkies/dist (optional)"
fi

# Warplay control binary (optional but expected for control).
if [ -f "${SELKIES_DIR}/dist/warplay-linux-control" ]; then
  cp "${SELKIES_DIR}/dist/warplay-linux-control" "${INSTALL_DIR}/"
else
  echo "[build] no warplay-linux-control in selkies/dist (did BUILD_CONTROL run?)"
fi

# Overlay mechanism for docker-selkies-egl-desktop/Dockerfile (SELKIES_SOURCE=local).
if [ -d "${SELKIES_DIR}/dist/copy_to_docker" ]; then
  mkdir -p "${INSTALL_DIR}/copy_to_docker"
  cp -an "${SELKIES_DIR}/dist/copy_to_docker/." "${INSTALL_DIR}/copy_to_docker/"
fi

echo "[build] docker build (${IMAGE_TAG}) ..."
(
  cd "${SCRIPT_DIR}"
  export DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-1}"
  docker build \
    --build-arg SELKIES_SOURCE="${SELKIES_SOURCE}" \
    --build-arg INSTALL_KASMVNC="${INSTALL_KASMVNC}" \
    --build-arg CACHE_BREAKER="${CACHE_BREAKER}" \
    -f "${DOCKERFILE}" \
    -t "${IMAGE_TAG}" \
    .
)

if [ "${DOCKER_IMAGES}" = "true" ]; then
  docker images -a || true
fi

if [ -n "${DOCKER_RM_CONTAINER}" ]; then
  docker rm -f "${DOCKER_RM_CONTAINER}" >/dev/null 2>&1 || true
fi

echo "[build] done: ${IMAGE_TAG}"
