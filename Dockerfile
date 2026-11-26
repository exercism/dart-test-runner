# ---- builder: the full Dart SDK, used to fetch deps and build the test snapshot ----
FROM dart:3.12 AS builder

WORKDIR /opt/test-runner

COPY pubspec.lock pubspec.yaml ./
RUN dart pub get

COPY bin/create-dart-snapshot.sh bin/create-dart-snapshot.sh
COPY premade/ premade/
RUN bin/create-dart-snapshot.sh

# `dart test` (JIT) only uses the dartdev / frontend_server / kernel-service snapshots.
# Drop what it never needs: the other tool snapshots (dart2js, analysis server, web
# dev compiler, wasm, bytecode, kernel worker, MCP server, tooling daemon, debug
# service), the sanitizer runtimes, DevTools and the compiler utilities - ~420 MB.
RUN cd /usr/lib/dart/bin && \
    rm -r dartaotruntime_asan dartaotruntime_msan dartaotruntime_tsan \
          resources/devtools utils && \
    cd snapshots && \
    rm analysis_server.dart.snapshot analysis_server_aot.dart.snapshot \
       dart2bytecode.dart.snapshot dart2js_aot.dart.snapshot \
       dart2wasm_product.snapshot dartdevc.dart.snapshot dartdevc_aot.dart.snapshot \
       gen_kernel_aot.dart.snapshot kernel_worker_aot.dart.snapshot \
       dart_mcp_server_aot.dart.snapshot dart_tooling_daemon_aot.dart.snapshot \
       dds_aot.dart.snapshot

# ---- final: the shared, pinned Debian 13 (trixie) slim base used by other tracks ----
# The Dart SDK links only glibc, and the builder image is also trixie based, so the
# SDK runs here unchanged - no full dart:3.12 needed.
FROM debian:trixie-slim@sha256:f6b08b09a05725f9431502d3b5714f5c4576e82c1a84fa1debe0c24a7e0c3ec4

RUN apt-get update && \
    apt-get install -y --no-install-recommends jq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV DART_SDK=/usr/lib/dart
ENV PATH=/usr/lib/dart/bin:/root/.pub-cache/bin:${PATH}

COPY --from=builder /usr/lib/dart /usr/lib/dart
COPY --from=builder /root/.pub-cache /root/.pub-cache

# Production runs with a read-only filesystem, where the `dart` command crashes if it
# can't create its analytics config in ~/.dart-tool. Create it now, with analytics off.
RUN dart --disable-analytics

# When pub runs, it records the project in the pub cache's active_roots folder, and
# warns if it can't. Nothing here reads those records, so point the folder at /tmp.
RUN rm -rf /root/.pub-cache/active_roots && ln -s /tmp /root/.pub-cache/active_roots

WORKDIR /opt/test-runner
COPY --from=builder /opt/test-runner /opt/test-runner
COPY . .

ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
