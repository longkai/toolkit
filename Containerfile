FROM debian:stable

LABEL org.opencontainers.image.description="Kennylong's toolkit\
currently mainly for containers/k8s/networking etc."

ARG CRANE_VERSION=0.20.1
ARG CIRCTL_VERSION=1.30.1
ARG NUSHELL_VERSION=0.96.1
ARG CARAPACE_VERSION=1.0.4
ARG STARSHIP_VERSION=1.20.1

WORKDIR /root

RUN apt-get update && apt-get install -y curl tcpdump iproute2 dnsutils netcat-openbsd iputils-tracepath iputils-ping iftop \
        vim less file zip bzip2 \
        htop procps \
        mariadb-client redis-tools

# the apt-get awscli is too old and the auto-completeion is not work
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
RUN arch="$(uname -m)"; \
    os="$(uname -s)"; \
    case "$os" in \
        Linux) os="linux" ;; \
        Darwin) os="osx" ;; \
    esac; \
    curl "https://awscli.amazonaws.com/awscli-exe-${os}-${arch}.zip" -o "awscliv2.zip"; \
    unzip awscliv2.zip; \
    ./aws/install; \
    rm -rf aws awscliv2.zip

RUN arch="$(uname -m)"; \
    case "$arch" in \
        x86_64) arch="amd64" ;; \
        aarch64) arch="arm64" ;; \
    esac; \
    os="$(uname -s)"; \
    case "$os" in \
        Linux) os="linux" ;; \
        Darwin) os="osx" ;; \
    esac; \
    # k8s \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/${os}/${arch}/kubectl"; \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl; \
    rm kubectl; \
    # crictl \
    curl -o crictl.tgz -L https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CIRCTL_VERSION}/crictl-v${CIRCTL_VERSION}-${os}-${arch}.tar.gz; \
    tar zxvf crictl.tgz -C /usr/local/bin; \
    rm crictl.tgz; \
    # helm \
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash; \
    # crane \
    arch="$(uname -m)"; \
    case "$arch" in \
        x86_64) arch="x86_64" ;; \
        aarch64) arch="arm64" ;; \
    esac; \
    os="$(uname -s)"; \
    case "$os" in \
        Linux) os="Linux" ;; \
        Darwin) os="Darwin" ;; \
    esac; \
    curl -o crane.tgz -L https://github.com/google/go-containerregistry/releases/download/v${CRANE_VERSION}/go-containerregistry_${os}_${arch}.tar.gz; \
    tar zxvf crane.tgz -C /usr/local/bin crane; \
    rm -rf crane.tgz

RUN libc=gnu; \
    arch="$(uname -m)"; \
    case "$arch" in \
        aarch64) arch="aarch64"; libc="musl" ;; \
    esac; \
    os="$(uname -s)"; \
    case "$os" in \
        Linux) os="linux" ;; \
        Darwin) os="osx" ;; \
    esac; \
    # nushell \
    curl -sSLo nu.tgz https://github.com/nushell/nushell/releases/download/${NUSHELL_VERSION}/nu-${NUSHELL_VERSION}-${arch}-unknown-${os}-gnu.tar.gz; \
    mkdir -p /opt/nushell; \
    tar zxvf nu.tgz -C /opt/nushell --strip-components=1; \
    rm -rf nu.tgz; \
    # starship \
    curl -sSLo starship.tgz https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-${arch}-unknown-${os}-${libc}.tar.gz; \
    tar zxvf starship.tgz -C /usr/local/bin; \
    rm -rf starship.tgz; \
    # carapace \
    arch="$(uname -m)"; \
    case "$arch" in \
        x86_64) arch="amd64" ;; \
        aarch64) arch="arm64" ;; \
    esac; \
    curl -sSLo carapace.tgz https://github.com/carapace-sh/carapace-bin/releases/download/v${CARAPACE_VERSION}/carapace-bin_${CARAPACE_VERSION}_${os}_${arch}.tar.gz; \
    tar zxvf carapace.tgz -C /usr/local/bin carapace; \
    rm -rf carapace.tgz

ADD nushell .config/nushell
ADD .vimrc .vimrc

# fix mysql client cjk encoding display issue
ENV LANG="C.utf8"
ENV PATH="$PATH:/opt/nushell"

ENTRYPOINT ["sleep", "infinity"]
