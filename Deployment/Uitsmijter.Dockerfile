# ----------------------------------------------------------------------------------------
# BUILD STAGE
# ----------------------------------------------------------------------------------------
ARG BASEIMAGE=swift:5.9.1-jammy
ARG BUILDBOX=2.1.1
FROM ghcr.io/uitsmijter/buildbox:${BUILDBOX} as build

# First resolve dependencies only.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Package.* ./
RUN swift package resolve

# Copy entire repo into container
COPY . .

# Test
ARG SKIPTESTS=false
RUN DIRECTORY=/build; \
    if [ "${SKIPTESTS}" != "true" ]; then \
      swift test \
      --scratch-path .build --num-workers 2 --parallel \
      -Xcc -I/usr/include/webkitgtk-4.0 \
      -Xcc -I/usr/include/webkitgtk-4.0/JavaScriptCore; fi

# Build everything, with optimizations
# --static-swift-stdlib - turned off while timer does not compile in static bins
RUN swift build -c release \
    -Xcc -I/usr/include/webkitgtk-4.0 \
    -Xcc -I/usr/include/webkitgtk-4.0/JavaScriptCore

# Switch to the staging area
WORKDIR /staging

# Copy main executable to staging area
RUN cp "$(swift build --package-path /build -c release --show-bin-path)/Uitsmijter" ./
RUN ls -la "$(swift build --package-path /build -c release --show-bin-path)/"

# Copy any resources from the public directory and views directory if the directories exist
# Ensure that by default, neither the directory nor any of its contents are writable.
RUN [ -d /build/Public ] && { mv /build/Public ./Public && chmod -R a+w ./Public; } || true
RUN [ -d /build/Resources ] && { mv /build/Resources ./Resources && chmod -R a+w ./Resources; } || true

# ========================================================================================

# ----------------------------------------------------------------------------------------
# APPLICATION STAGE
# ----------------------------------------------------------------------------------------

ARG BASEIMAGE
FROM ${BASEIMAGE}-slim as runtime

LABEL maintainer="aus der Technik"
LABEL Description="Uitsmijter Runtime"


# Make sure all system packages are up to date.
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
    apt-get -q update && apt-get -q dist-upgrade -y \
    && apt-get -q install -y \
    ca-certificates \
    libjavascriptcoregtk-4.0 \
    && rm -r /var/lib/apt/lists/*

# Create a uitsmijter user and group with /app as its home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app uitsmijter

# Switch to the new home directory
WORKDIR /app

# Copy built executable and any staged resources from builder
COPY --from=build --chown=uitsmijter:uitsmijter /staging /app

# Ensure all further commands run as the uitsmijter user
USER uitsmijter:uitsmijter

# Let Docker bind to port 8080
EXPOSE 8080

# Start the service when the image is run, default to listening on 8080 in production environment
ENTRYPOINT ["./Uitsmijter"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
