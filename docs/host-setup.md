# Host setup notes (Docker, AMD, GitHub)

This file is a local note to keep commonly used host setup commands in one place.

## AMD container toolkit (Ubuntu)

Install prerequisites:

```bash
sudo apt update
sudo apt install -y wget gpg
sudo mkdir -p /etc/apt/keyrings
wget https://repo.radeon.com/rocm/rocm.gpg.key -O - | gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null
```

### Ubuntu 24.04 (noble)

```bash
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/amd-container-toolkit/apt/ noble main" | \
  sudo tee /etc/apt/sources.list.d/amd-container-toolkit.list
sudo apt update
sudo apt install -y amd-container-toolkit
```

### Ubuntu 22.04 (jammy)

```bash
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/amd-container-toolkit/apt/ jammy main" | \
  sudo tee /etc/apt/sources.list.d/amd-container-toolkit.list
sudo apt update
sudo apt install -y amd-container-toolkit
```

Post-install (Docker runtime wiring):

```bash
sudo amd-ctk runtime configure --runtime=docker
sudo systemctl restart docker

sudo amd-ctk runtime configure --runtime=docker --set-as-default
sudo systemctl restart docker

amd-ctk cdi list
```

## GitHub bot / tokens (DO NOT paste secrets)

Never commit or paste PATs/passwords into docs, shell history, or `git config credential.helper store`.

Use placeholders and inject secrets at runtime via your CI secret store or prompt:

```bash
GH_USER='your-bot-user'
GH_TOKEN='***'
```

If you need to authenticate for `git clone`, prefer:
- SSH deploy keys, or
- `gh auth login`, or
- CI-provided `GITHUB_TOKEN` / fine-grained PAT stored in secrets.

