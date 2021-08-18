FROM golang:1.16.7 as go

WORKDIR /plugin

COPY . .

RUN make clean build-linux

FROM buildkite/plugin-tester

COPY . .

COPY --from=go \
  /plugin/monorepo-diff-buildkite-plugin-linux \
  /usr/bin/monorepo-diff-buildkite-plugin
