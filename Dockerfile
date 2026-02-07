FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

# Standard paths you want
ENV CODEX_HOME=/codex
ENV MISE_DATA_DIR=/codex/mise
ENV MISE_CACHE_DIR=/codex/mise-cache
ENV MISE_TMP_DIR=/tmp/mise
ENV REPO_DIR=/repo

# Put mise shims early; put Codex bin on PATH
ENV PATH="/opt/codex/bin:${MISE_DATA_DIR}/shims:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Base tooling + build deps for Python builds + general native deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg \
    git openssh-client openssh-server \
    build-essential pkg-config \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
    libffi-dev liblzma-dev tk-dev uuid-dev \
    xz-utils unzip zip \
    python3 python3-venv python3-pip \
    jq ripgrep \
    iptables uidmap \
    && rm -rf /var/lib/apt/lists/*

# Docker Engine + Compose plugin (official Docker apt repo)
# Ref: https://docs.docker.com/engine/install/debian/  [oai_citation:4‡Docker Documentation](https://docs.docker.com/engine/install/debian/?utm_source=chatgpt.com)
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl; \
    install -m 0755 -d /etc/apt/keyrings; \
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc; \
    chmod a+r /etc/apt/keyrings/docker.asc; \
    . /etc/os-release; \
    echo "Types: deb\nURIs: https://download.docker.com/linux/debian\nSuites: ${VERSION_CODENAME}\nComponents: stable\nSigned-By: /etc/apt/keyrings/docker.asc" \
      > /etc/apt/sources.list.d/docker.sources; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; \
    rm -rf /var/lib/apt/lists/*

# Install mise (single binary)
# Ref: https://mise.run install method  [oai_citation:5‡Mise en Place](https://mise.jdx.dev/installing-mise.html?utm_source=chatgpt.com)
RUN set -eux; \
    curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh; \
    mkdir -p "${MISE_DATA_DIR}" "${MISE_CACHE_DIR}" "${MISE_TMP_DIR}"

# Install a Node just to install Codex, then install Codex into /opt/codex
# Codex install method: npm i -g @openai/codex  [oai_citation:6‡OpenAI Developers](https://developers.openai.com/codex/cli?utm_source=chatgpt.com)
RUN set -eux; \
    mise --version; \
    mise use -g node@lts; \
    node --version; \
    npm --version; \
    mkdir -p /opt/codex; \
    npm config set prefix /opt/codex; \
    npm i -g @openai/codex; \
    codex --version || true

# Minimal sshd setup (keys generated at runtime in entrypoint)
RUN mkdir -p /var/run/sshd

# Entrypoint: start dockerd (rootful) + launch codex
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /repo
VOLUME ["/codex", "/repo", "/var/lib/docker"]
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["codex"]
