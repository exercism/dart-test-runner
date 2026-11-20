# ---- builder: the full Dart SDK, used to fetch deps and build the test snapshot ----
FROM dart:3.12 AS builder

WORKDIR /opt/test-runner

COPY pubspec.lock pubspec.yaml ./
RUN dart pub get

COPY bin/create-dart-snapshot.sh bin/create-dart-snapshot.sh
COPY premade/ premade/
RUN bin/create-dart-snapshot.sh

# `dart test` (JIT) only uses the dartdev / frontend_server / kernel-service snapshots.
# Drop the tool snapshots it never needs (dart2js, analysis server, web dev compiler,
# wasm, AOT/kernel-worker) - ~230 MB.
RUN cd /usr/lib/dart/bin/snapshots && \
    rm -f dart2js.dart.snapshot analysis_server.dart.snapshot dartdevc.dart.snapshot \
          kernel_worker.dart.snapshot gen_kernel_aot.dart.snapshot dart2wasm_product.snapshot

# ---- final: the shared, pinned Debian 13 (trixie) slim base used by other tracks ----
# The Dart SDK links only glibc, and trixie's glibc (2.41) is newer than the bookworm
# (2.36) it was built against, so the SDK runs here unchanged - no full dart:3.2 needed.
FROM debian:trixie-slim@sha256:f6b08b09a05725f9431502d3b5714f5c4576e82c1a84fa1debe0c24a7e0c3ec4

RUN apt-get update && \
    apt-get install -y --no-install-recommends jq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV DART_SDK=/usr/lib/dart
ENV PATH=/usr/lib/dart/bin:/root/.pub-cache/bin:${PATH}

COPY --from=builder /usr/lib/dart /usr/lib/dart
COPY --from=builder /root/.pub-cache /root/.pub-cache

WORKDIR /opt/test-runner
COPY --from=builder /opt/test-runner /opt/test-runner
COPY . .

ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
