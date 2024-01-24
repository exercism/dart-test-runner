FROM dart:2.18

RUN apt-get update && \
    apt-get install -y jq && \
    apt-get purge --auto-remove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/test-runner

COPY pubspec.lock pubspec.yaml ./
RUN dart pub get

COPY bin/create-dart-snapshot.sh bin/create-dart-snapshot.sh
COPY premade/ premade/
RUN bin/create-dart-snapshot.sh

COPY . .

ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
