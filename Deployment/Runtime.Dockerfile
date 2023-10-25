# ----------------------------------------------------------------------------------------
# APPLICATION RUNTIME
# ----------------------------------------------------------------------------------------
ARG BASEIMAGE
FROM ${BASEIMAGE}-slim as runtime

LABEL maintainer="aus der Technik"
LABEL Description="Uitsmijter"


# Make sure all system packages are up to date.
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true
RUN apt-get -q update && apt-get -q dist-upgrade -y \
    && apt-get -q install -y \
    ca-certificates \
    libjavascriptcoregtk-4.0 \
    && rm -r /var/lib/apt/lists/*

# Create a uitsmijter user and group with /app as its home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app uitsmijter

WORKDIR /
ADD Deployment/entrypoint.sh /app/entrypoint.sh
ADD --chown=uitsmijter:uitsmijter Deployment/Runtime/.env Deployment/Runtime/dirt? /app

# Ensure all further commands run as the uitsmijter user
USER uitsmijter:uitsmijter

# Let Docker bind to port 8080
EXPOSE 8080

ENTRYPOINT ["/app/entrypoint.sh"]
