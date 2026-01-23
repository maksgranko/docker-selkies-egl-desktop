# Build / update commands (safe, updated)

This document rewrites the previously shared build commands to match the current repo state:

- Selkies offline/local install is controlled by `SELKIES_SOURCE=local` (not `SELKIES_LOCAL_DIR`).
- Selkies artifacts are expected in `docker-selkies-egl-desktop/install_to_docker/` (or `install_to_docker/selkies/`).
- `wp_drivers` support was removed from the Dockerfile.
- Offline build requires BuildKit (`DOCKER_BUILDKIT=1`) because the Dockerfile uses `RUN --mount=type=bind`.

## 0) Safety: credentials

Do not paste or commit secrets (PATs/passwords) into scripts or docs.

Use placeholders and inject secrets via your CI secret store:

```bash
GH_USER='your-bot-user'
GH_TOKEN='***'
```

## 1) Clone repositories (example)

Prefer SSH deploy keys (recommended) or `gh auth login`. If you must use HTTPS tokens, avoid `credential.helper store`.

```bash
rm -rf github
mkdir -p github
cd github

git clone -b new-main https://github.com/WARPLAY-CLOUD/selkies.git
git clone -b new-main https://github.com/WARPLAY-CLOUD/docker-selkies-egl-desktop.git
```

## 2) Build Selkies artifacts locally (produces `dist/*`)

```bash
cd github/selkies
chmod +x build.sh
./build.sh
```

## 3) Offline build (single command)

This replaces the old “local build” variants. It:
1) builds Selkies (`./build.sh`)
2) copies `dist/*` into `docker-selkies-egl-desktop/install_to_docker/`
3) builds the desktop image with `SELKIES_SOURCE=local`

```bash
cd github/selkies && chmod +x build.sh && ./build.sh && \
cd .. && mkdir -p docker-selkies-egl-desktop/install_to_docker && \
# GStreamer bundle can be pre-seeded already; copy only if present, don't overwrite, don't fail if missing
if ls selkies/dist/gstreamer-selkies_gpl_v*.tar.gz >/dev/null 2>&1; then \
  cp -n selkies/dist/gstreamer-selkies_gpl_v*.tar.gz docker-selkies-egl-desktop/install_to_docker/; \
else \
  echo "No GStreamer bundle in selkies/dist (ok if already present in install_to_docker/)"; \
fi && \
cp selkies/dist/selkies_gstreamer-*.whl docker-selkies-egl-desktop/install_to_docker/ && \
cp selkies/dist/selkies-gstreamer-web_v*.tar.gz docker-selkies-egl-desktop/install_to_docker/ && \
cp selkies/dist/selkies-js-interposer_v*.deb docker-selkies-egl-desktop/install_to_docker/ && \
cd docker-selkies-egl-desktop && \
DOCKER_BUILDKIT=1 docker build --build-arg SELKIES_SOURCE=local --build-arg CACHE_BREAKER="$(date +%Y%m%d%H%M%S)" -f Dockerfile -t selkies-egl-desktop:local .
```

## 4) Build the desktop image

### Offline / local Selkies artifacts (no CDN)

```bash
cd github/docker-selkies-egl-desktop

DOCKER_BUILDKIT=1 docker build \
  --build-arg SELKIES_INSTALL=true \
  --build-arg SELKIES_SOURCE=local \
  --build-arg INSTALL_KASMVNC=true \
  --build-arg CACHE_BREAKER="$(date +%Y%m%d%H%M%S)" \
  -f Dockerfile \
  -t selkies-egl-desktop:local \
  .
```

### CDN mode (default)

```bash
cd github/docker-selkies-egl-desktop

docker build \
  --build-arg SELKIES_INSTALL=true \
  --build-arg SELKIES_SOURCE=cdn \
  --build-arg INSTALL_KASMVNC=true \
  --build-arg CACHE_BREAKER="$(date +%Y%m%d%H%M%S)" \
  -f Dockerfile \
  -t selkies-egl-desktop:cdn \
  .
```

### Disable Selkies (skips the GStreamer bundle)

If you want a smaller image and plan to use only KasmVNC (or you don't need the Selkies WebRTC stack), disable Selkies at build time:

```bash
DOCKER_BUILDKIT=1 docker build \
  --build-arg SELKIES_INSTALL=false \
  --build-arg SELKIES_SOURCE=cdn \
  --build-arg INSTALL_KASMVNC=true \
  -f Dockerfile \
  -t selkies-egl-desktop:no-selkies \
  .
```

### Disable KasmVNC download (faster build)

KasmVNC is optional if you only use the Selkies WebRTC interface. Disable it at build time:

```bash
docker build \
  --build-arg SELKIES_SOURCE=cdn \
  --build-arg INSTALL_KASMVNC=false \
  -f Dockerfile \
  -t selkies-egl-desktop:no-kasmvnc \
  .
```

## 5) Run (example)

This remains the same idea as before. Choose encoder based on your GPU:

- NVIDIA: `SELKIES_ENCODER=nvh264enc`
- AMD/Intel VAAPI: `SELKIES_ENCODER=vah264enc`
- CPU fallback: `SELKIES_ENCODER=x264enc`

```bash
docker rm -f egl 2>/dev/null || true
docker run --name egl -d -it \
  --network=host \
  --tmpfs /dev/shm:rw,size=2G \
  --device /dev/uinput \
  -v "$HOME/egl-data:/home/ubuntu" \
  -e TZ=UTC \
  -e DISPLAY_SIZEW=1920 -e DISPLAY_SIZEH=1080 \
  -e DISPLAY_REFRESH=60 -e DISPLAY_DPI=96 -e DISPLAY_CDEPTH=24 \
  -e PASSWD=mypasswd \
  -e SELKIES_ENCODER=x264enc \
  -e SELKIES_VIDEO_BITRATE=8000 \
  -e SELKIES_FRAMERATE=60 \
  -e SELKIES_AUDIO_BITRATE=128000 \
  -e SELKIES_ENABLE_BASIC_AUTH=true \
  -e SELKIES_BASIC_AUTH_PASSWORD=mypasswd \
  selkies-egl-desktop:local
```
