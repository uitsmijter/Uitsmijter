# ----------------------------------------------------------------------------------------
# Kubernetes kubectl
# ----------------------------------------------------------------------------------------
FROM bitnami/kubectl AS kubectl

# ----------------------------------------------------------------------------------------
# E2E TEST RUNTIME
# ----------------------------------------------------------------------------------------
FROM node:20-bullseye

LABEL maintainer="aus der Technik"
LABEL Description="Uitsmijter e2e"

ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true
RUN apt update -q \
    && apt dist-upgrade -q -y \
    && apt install -y apt-utils apt-transport-https
RUN apt install -y \
    yamllint

# Kubernetes & Helm
COPY --from=kubectl /opt/bitnami/kubectl/bin/kubectl /usr/bin/kubectl
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install dependencies
RUN yarn global add playwright; \
    npx playwright install-deps

# Rename the node user and group to uitsmijter
RUN usermod -l uitsmijter node && groupmod -n uitsmijter node

# Ensure all further commands run as the uitsmijter user
USER uitsmijter:uitsmijter

WORKDIR /tests

ENTRYPOINT [ ]
CMD [ "bash" ]
