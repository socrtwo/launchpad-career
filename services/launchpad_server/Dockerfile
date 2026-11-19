# Launchpad Career server.
#
# Build from this directory:
#   docker build -t launchpad-server .
#
# Stage 1 compiles a self-contained executable. Stage 2 contains only that
# executable and the few shared libraries it needs: no shell, no package
# manager, no Dart SDK.

FROM dart:stable AS build
WORKDIR /app

# Resolve dependencies first so this layer is reused until they change.
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get

COPY bin ./bin
COPY lib ./lib
RUN dart pub get --offline \
 && dart compile exe bin/server.dart -o /app/server

# The data directory is created here because the runtime image has no shell.
# Only the server's own user may enter it: the data file holds passphrase
# hashes and synced profile documents.
RUN mkdir -p /out/data && chmod 700 /out/data

FROM scratch

# /runtime holds the libraries a compiled Dart executable links against.
COPY --from=build /runtime/ /
COPY --from=build /app/server /app/server
COPY --from=build --chown=10001:10001 /out/data /data

# An unprivileged, numeric user: nothing in this image needs root.
USER 10001:10001

ENV PORT=8080 \
    DATA_FILE=/data/launchpad.json

VOLUME ["/data"]
EXPOSE 8080

ENTRYPOINT ["/app/server"]
