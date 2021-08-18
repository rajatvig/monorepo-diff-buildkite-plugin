FROM golang:1.17.2 as go

WORKDIR /plugin

COPY . .

RUN make clean build-linux

FROM buildkite/plugin-tester

COPY . .

COPY --from=go \
  /plugin/monorepo-diff-buildkite-plugin-linux-amd64 \
  /usr/bin/monorepo-diff-buildkite-plugin
