# ----------------------------------------------------------------------------------------
# BUILD STAGE
# ----------------------------------------------------------------------------------------
ARG BASEIMAGE_CODE=ubuntu:22.04
ARG SWIFT_VERSION

FROM ${BASEIMAGE_CODE}
LABEL maintainer="aus der Technik"
LABEL Description="UItsmijter - Code-Server"

# Install OS updates and, if needed
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
RUN apt-get update && apt-get install -y apt-utils apt-transport-https
RUN apt update \
    && apt dist-upgrade -y
RUN apt install -y \
    libz-dev \
    curl libcurl4-openssl-dev wget \
    gnupg openssh-client \
    git jq unzip \
    libjavascriptcoregtk-4.0-dev \
    python3.10 libpython3.10 python3-pip \
    binutils \
    glibc-tools gcc \
    cmake

# Setting up Project dir
# ----------------------------------------------------------------------------------------
RUN mkdir /Project && chmod 777 /Project
COPY Deployment/code-server/entrypoint.sh /entrypoint.sh


# Install Swift
# ----------------------------------------------------------------------------------------
WORKDIR /build
RUN echo "install..."; \
  if [ "$(arch)" = "aarch64" ]; then \
    ADD_ARCH="-$(arch)"; \
  fi; \
  echo "Arch: ${ADD_ARCH}"; \
  echo "Version: ${SWIFT_VERSION}"; \
  exit 1; \
  SWIFT_URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2204${ADD_ARCH}/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu22.04${ADD_ARCH}.tar.gz"; \
  echo "Swift download from: ${SWIFT_URL}" > /swift_download.txt; \
  wget ${SWIFT_URL}; \
  tar -xvzf swift-${SWIFT_VERSION}-RELEASE-ubuntu22.04${ADD_ARCH}.tar.gz; \
  cd swift-${SWIFT_VERSION}-RELEASE-ubuntu22.04${ADD_ARCH}; \
  cp -rv -T ./usr/. /usr; \
  cd /; rm -rf /build/__*; ##FIXME

# Install NodeJS
# ----------------------------------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs


# Install Code-Server
# ----------------------------------------------------------------------------------------
RUN mkdir /extensions
RUN chmod -R 777 /extensions
ADD Deployment/code-server/*.vsix /extensions/install/
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Run this as a user

# Install publice xtensions  
RUN for ext in sswg.swift-lang vadimcn.vscode-lldb zaaack.markdown-editor ms-toolsai.jupyter ms-python.python; do \
  code-server --disable-telemetry --extensions-dir /extensions --install-extension ${ext}; \
  done;

# Install user extensions
RUN for ext in $(find /extensions/install/ -name "*.vsix"); do \
  code-server --disable-telemetry --extensions-dir /extensions --install-extension ${ext}; \
  done;

RUN rm -rf /extensions/install/*

# Install Kernels
# ----------------------------------------------------------------------------------------
RUN pip install bash_kernel; python3 -m bash_kernel.install

# Setting the startp
# ----------------------------------------------------------------------------------------
WORKDIR /Project
COPY Deployment/code-server/config.yaml /root/.config/code-server/config.yaml
EXPOSE 31546
ENTRYPOINT ["/entrypoint.sh"]
