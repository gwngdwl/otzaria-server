# Build context must be the repository root:
# docker build -f apps/server/Dockerfile -t otzaria-server .
FROM dart:stable AS build

WORKDIR /repo

# Resolve dependencies first for better Docker layer caching. The server depends
# on the local otzaria_core package, so both pubspecs must be in the build context.
COPY apps/server/pubspec.* apps/server/
COPY packages/otzaria_core/pubspec.* packages/otzaria_core/
WORKDIR /repo/apps/server
RUN dart pub get

WORKDIR /repo
COPY packages/otzaria_core/ packages/otzaria_core/
COPY apps/server/ apps/server/

WORKDIR /repo/apps/server
RUN dart build cli --target bin/server.dart -o output

# Build a minimal serving image from the AOT bundle and the pre-built Dart
# runtime in the base image. The sqlite3 native asset is copied in the bundle.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /repo/apps/server/output/bundle/ /app/

ENV PORT=8080
EXPOSE 8080
CMD ["/app/bin/server"]
